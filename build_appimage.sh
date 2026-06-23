#!/bin/bash
# Copyright (c) 2026-present, Dwyco, Inc.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at https://mozilla.org/MPL/2.0/.

#
# Build and package script for SkimView Qt6 app on Linux (AppImage)
# Usage: ./build_appimage.sh [--clean] [--output-dir <dir>] [--skip-build] [--help]

set -e

# ---------------------------------------------------------------------------
# Configuration defaults
# ---------------------------------------------------------------------------
QT_PATH="${QT_PATH:-$HOME/Qt/6.11.1/gcc_64}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/skimview-build"
APPDIR="$BUILD_DIR/AppDir"
TOOL_DIR="/tmp/skimview-appimage"
APP_NAME="SkimView"
VERSION_FILE="$PROJECT_DIR/VERSION.txt"

# linuxdeploy URLs
LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_PLUGIN_QT_URL="https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage"

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
show_help() {
    cat <<EOF
Usage: $0 [options]

Options:
  --clean             Remove previous build directory before starting
  --output-dir <dir>  Directory to place the final AppImage (default: project root)
  --skip-build        Skip cmake configure & build; only re-package AppDir
  --help              Show this help message

Environment variables:
  QT_PATH             Path to Qt installation (default: $HOME/Qt/6.11.1/gcc_64)
  LINUXDEPLOY_PATH    Path to linuxdeploy (auto-downloaded if not set)
EOF
    exit 0
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
CLEAN=false
SKIP_BUILD=false
OUTPUT_DIR="$PROJECT_DIR"

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=true
            shift
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------
generate_version() {
    local major
    major=$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null || echo "0")
    local build sha
    build=$(git -C "$PROJECT_DIR" rev-list --count HEAD 2>/dev/null || echo "0")
    sha=$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    echo "${major}+${build}-${sha}"
}

VERSION=$(generate_version)
echo "SkimView version: $VERSION"

# Add Qt binaries to PATH for macdeployqt-style tool discovery
export PATH="$QT_PATH/bin:$PATH"

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
check_deps() {
    local missing=0

    if ! command -v cmake &>/dev/null; then
        echo "Error: cmake is not installed."
        echo "  Install: sudo apt install cmake"
        missing=1
    fi

    if ! command -v ninja &>/dev/null && ! command -v make &>/dev/null; then
        echo "Error: neither ninja nor make is installed."
        echo "  Install: sudo apt install ninja-build"
        missing=1
    fi

    if ! command -v g++ &>/dev/null; then
        echo "Error: g++ is not installed."
        echo "  Install: sudo apt install g++"
        missing=1
    fi

    if [ ! -f "$QT_PATH/lib/cmake/Qt6/Qt6Config.cmake" ]; then
        echo "Error: Qt 6.11.1 not found at $QT_PATH"
        echo "  Install from: https://www.qt.io/download-qt-installer"
        echo "  Or set QT_PATH to your Qt installation"
        missing=1
    fi

    if [ "$missing" -ne 0 ]; then
        exit 1
    fi

    echo "All build dependencies found."
}

check_deps

# ---------------------------------------------------------------------------
# Acquire linuxdeploy
# ---------------------------------------------------------------------------
ensure_linuxdeploy() {
    if [ -n "$LINUXDEPLOY_PATH" ]; then
        echo "$LINUXDEPLOY_PATH"
        return
    fi

    mkdir -p "$TOOL_DIR"
    local LD="$TOOL_DIR/linuxdeploy-x86_64.AppImage"
    local QT_PLUGIN="$TOOL_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"

    if [ ! -f "$LD" ]; then
        echo "Downloading linuxdeploy..." >&2
        if command -v curl &>/dev/null; then
            curl -sL -o "$LD" "$LINUXDEPLOY_URL"
        elif command -v wget &>/dev/null; then
            wget -q -O "$LD" "$LINUXDEPLOY_URL"
        else
            echo "Error: need curl or wget to download linuxdeploy" >&2
            exit 1
        fi
        chmod +x "$LD"
    fi

    if [ ! -f "$QT_PLUGIN" ]; then
        echo "Downloading linuxdeploy-plugin-qt..." >&2
        if command -v curl &>/dev/null; then
            curl -sL -o "$QT_PLUGIN" "$LINUXDEPLOY_PLUGIN_QT_URL"
        elif command -v wget &>/dev/null; then
            wget -q -O "$QT_PLUGIN" "$LINUXDEPLOY_PLUGIN_QT_URL"
        else
            echo "Error: need curl or wget to download linuxdeploy-plugin-qt" >&2
            exit 1
        fi
        chmod +x "$QT_PLUGIN"
    fi

    echo "$LD"
}

LINUXDEPLOY=$(ensure_linuxdeploy)

# Ensure linuxdeploy can run without FUSE
export APPIMAGE_EXTRACT_AND_RUN=1

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
if [ "$CLEAN" = true ]; then
    echo "Cleaning previous build..."
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

if [ "$SKIP_BUILD" = false ]; then
    echo ""
    echo "=========================================="
    echo "Configuring with CMake..."
    echo "=========================================="
    cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH="$QT_PATH" \
        -GNinja

    echo ""
    echo "=========================================="
    echo "Building..."
    echo "=========================================="
    cmake --build "$BUILD_DIR" --parallel
else
    echo "Skipping build (--skip-build). Using existing binaries in $BUILD_DIR"
fi

BINARY="$BUILD_DIR/$APP_NAME"
if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    echo "Make sure the build completed successfully."
    exit 1
fi
echo "Binary: $BINARY"

# ---------------------------------------------------------------------------
# Prepare AppDir
# ---------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Preparing AppDir..."
echo "=========================================="

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# Copy binary
cp "$BINARY" "$APPDIR/usr/bin/$APP_NAME"

# Copy tools (tag_images.py) next to binary so findScript() finds it
cp -r "$BUILD_DIR/tools" "$APPDIR/usr/bin/"

# Copy desktop file
cp "$PROJECT_DIR/$APP_NAME.desktop" "$APPDIR/usr/share/applications/"

# Copy icon
cp "$PROJECT_DIR/icon.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/skimview.png"

# Symlink icon in legacy location that linuxdeploy also checks
ln -sf "usr/share/applications/$APP_NAME.desktop" "$APPDIR/$APP_NAME.desktop"

# ---------------------------------------------------------------------------
# Bundle with linuxdeploy
# ---------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Running linuxdeploy with Qt plugin..."
echo "=========================================="

export LDAI_OUTPUT="$BUILD_DIR/${APP_NAME}-${VERSION}-x86_64.AppImage"

# Set QML sources so linuxdeploy-plugin-qt QML imports are bundled
export QML_SOURCES_PATHS="$PROJECT_DIR"

# Temporarily remove non-SQLite SQL driver plugins to avoid missing library
# dependencies (libodbc, libpq, libclntsh, etc.). SkimView only uses SQLite.
SQL_DRIVERS="$QT_PATH/plugins/sqldrivers"
SQL_HIDDEN="$(mktemp -d)"
for plugin in "$SQL_DRIVERS"/libqsql*.so; do
    name=$(basename "$plugin" .so)
    if [ "$name" != "libqsqlite" ]; then
        mv "$plugin" "$SQL_HIDDEN/" 2>/dev/null || true
    fi
done

"$LINUXDEPLOY" \
    --appdir "$APPDIR" \
    --plugin qt \
    --output appimage \
    --desktop-file "$APPDIR/usr/share/applications/$APP_NAME.desktop" \
    --icon-file "$APPDIR/usr/share/icons/hicolor/256x256/apps/skimview.png"

# Restore all hidden SQL driver plugins
mv "$SQL_HIDDEN"/*.so "$SQL_DRIVERS/" 2>/dev/null || true
rmdir "$SQL_HIDDEN" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Copy output to final location
# ---------------------------------------------------------------------------
OUTPUT_APPIMAGE="$BUILD_DIR/${APP_NAME}-${VERSION}-x86_64.AppImage"
if [ -f "$OUTPUT_APPIMAGE" ]; then
    mkdir -p "$OUTPUT_DIR"
    FINAL_PATH="$OUTPUT_DIR/${APP_NAME}-${VERSION}-x86_64.AppImage"
    rm -f "$FINAL_PATH"
    cp "$OUTPUT_APPIMAGE" "$FINAL_PATH"
    echo ""
    echo "=========================================="
    echo "Build Complete!"
    echo "=========================================="
    echo "AppImage: $FINAL_PATH"
    echo "Size:     $(du -h "$FINAL_PATH" | cut -f1)"
else
    echo "Error: AppImage output not found at $OUTPUT_APPIMAGE"
    echo "Check linuxdeploy output above for details."
    echo "The AppDir is still available at: $APPDIR"
    exit 1
fi
