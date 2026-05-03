#!/bin/bash

# Build and package script for ImageViewer Qt6 app
# Usage: ./build_dmg.sh [--sign] [--identity "Developer ID Application: Your Name"]

set -e

# Configuration
QT_PATH="$HOME/Qt/6.11.0/macos"
APP_NAME="ImageViewer"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
INSTALL_DIR="$BUILD_DIR/install"
DMG_DIR="$BUILD_DIR/dmg"

# Parse arguments
SIGN_APP=false
SIGN_IDENTITY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --sign)
            SIGN_APP=true
            shift
            ;;
        --identity)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--sign] [--identity \"Developer ID Application: Your Name\"]"
            echo ""
            echo "Options:"
            echo "  --sign              Enable code signing (requires valid certificate)"
            echo "  --identity <id>    Specify signing identity (default: auto-detect)"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "Building $APP_NAME"
echo "=========================================="
echo "Qt path: $QT_PATH"
echo "Build dir: $BUILD_DIR"
echo "Sign app: $SIGN_APP"
if [ "$SIGN_APP" = true ]; then
    echo "Identity: ${SIGN_IDENTITY:-auto-detect}"
fi
echo ""

# Check Qt installation
if [ ! -d "$QT_PATH" ]; then
    echo "Error: Qt not found at $QT_PATH"
    exit 1
fi

# Clean previous build
echo "Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Configure with CMake
echo "Configuring with CMake..."
cd "$BUILD_DIR"
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="$QT_PATH" \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"

# Build
echo "Building..."
cmake --build . --config Release --parallel

# Find the app bundle
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found at $APP_BUNDLE"
    exit 1
fi

echo "App bundle created: $APP_BUNDLE"

# Run macdeployqt
echo "Running macdeployqt..."
"$QT_PATH/bin/macdeployqt" "$APP_BUNDLE" \
    -verbose=1 \
    -always-overwrite

# Optional: Code signing
if [ "$SIGN_APP" = true ]; then
    echo ""
    echo "=========================================="
    echo "Code Signing"
    echo "=========================================="

    # Auto-detect identity if not provided
    if [ -z "$SIGN_IDENTITY" ]; then
        SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')
        if [ -z "$SIGN_IDENTITY" ]; then
            echo "Warning: No 'Developer ID Application' identity found. Trying to find any valid identity..."
            SIGN_IDENTITY=$(security find-identity -v -p codesigning | head -1 | awk -F'"' '{print $2}')
        fi
    fi

    if [ -z "$SIGN_IDENTITY" ]; then
        echo "Error: No valid code signing identity found"
        echo "Available identities:"
        security find-identity -v -p codesigning
        exit 1
    fi

    echo "Using identity: $SIGN_IDENTITY"

    # Sign the app bundle
    echo "Signing $APP_BUNDLE..."
    codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE" --verbose

    # Verify signature
    echo "Verifying signature..."
    codesign --verify --verbose "$APP_BUNDLE"
    if [ $? -eq 0 ]; then
        echo "Signature verified successfully"
    else
        echo "Warning: Signature verification failed"
    fi
fi

# Create DMG
echo ""
echo "=========================================="
echo "Creating DMG"
echo "=========================================="

# Clean up DMG directory
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Copy app to DMG directory
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create DMG
DMG_NAME="$APP_NAME-$(date +%Y%m%d).dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

echo "Creating DMG: $DMG_PATH"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Optional: Sign the DMG
if [ "$SIGN_APP" = true ] && [ -n "$SIGN_IDENTITY" ]; then
    echo "Signing DMG..."
    codesign --force --sign "$SIGN_IDENTITY" "$DMG_PATH" --verbose
fi

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo "App bundle: $APP_BUNDLE"
echo "DMG file: $DMG_PATH"
echo ""
echo "To install, open the DMG and drag $APP_NAME.app to Applications"
