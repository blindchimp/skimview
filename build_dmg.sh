#!/bin/bash
#
# WARNING: vibe coded, 2026

# Build and package script for ImageViewer Qt6 app
# Usage: ./build_dmg.sh [--sign] [--identity "Developer ID Application: Your Name"] [--notarize]

set -e

# Configuration
QT_PATH="$HOME/Qt/6.11.1/macos"
QT_BIN="$QT_PATH/bin"
APP_NAME="ImageViewer"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/build"
INSTALL_DIR="$BUILD_DIR/install"
DMG_DIR="$BUILD_DIR/dmg"

# Add Qt bin to PATH so all bundling commands are found in the same place
export PATH="$QT_BIN:$PATH"

# Parse arguments
SIGN_APP=false
SIGN_IDENTITY=""
NOTARIZE=false

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
        --notarize)
            NOTARIZE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--sign] [--identity \"Developer ID Application: Your Name\"] [--notarize]"
            echo ""
            echo "Options:"
            echo "  --sign              Enable code signing (requires valid certificate)"
            echo "  --identity <id>    Specify signing identity (default: auto-detect)"
            echo "  --notarize         Enable notarization (requires 'notary' profile configured)"
            echo "  --help             Show this help message"
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
echo "Notarize: $NOTARIZE"
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
cmake "$PROJECT_DIR" \
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
MACDEPLOYQT_ARGS=("$APP_BUNDLE" -qmldir="$PROJECT_DIR" -verbose=1 -always-overwrite)

# Add DMG creation
DMG_NAME="$APP_NAME.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
MACDEPLOYQT_ARGS+=(-dmg "$DMG_PATH")

# Add code signing if requested
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
	if [ "$NOTARIZE" = true ]; then
	    MACDEPLOYQT_ARGS+=(-sign-for-notarization="$SIGN_IDENTITY")
	else
	    MACDEPLOYQT_ARGS+=(-codesign="$SIGN_IDENTITY")
	fi
fi

# Run macdeployqt with all options
macdeployqt "${MACDEPLOYQT_ARGS[@]}"

# not sure why macdeployqt doesn't sign the resulting dmg when you ask it to
if [ "$SIGN_APP" = true ]; then
	codesign -s "$SIGN_IDENTITY" "$DMG_PATH"
fi

# Notarization if requested
if [ "$NOTARIZE" = true ]; then
    if [ ! -f "$DMG_PATH" ]; then
        echo "Error: DMG file not found at $DMG_PATH, cannot notarize"
        exit 1
    fi

    echo ""
    echo "=========================================="
    echo "Notarization"
    echo "=========================================="

    echo "Submitting DMG for notarization using 'notary' profile..."
    echo "This may take a few minutes..."

    # Submit for notarization using profile
    NOTARIZE_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile notary \
        --wait \
        --output-format json)

    echo "$NOTARIZE_OUTPUT"

    # Check if notarization succeeded
    NOTARIZE_STATUS=$(echo "$NOTARIZE_OUTPUT" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

    if [ "$NOTARIZE_STATUS" = "Accepted" ]; then
        echo "Notarization successful!"

        echo ""
        echo "Stapling notarization ticket..."
        xcrun stapler staple "$DMG_PATH"

        echo "Stapling complete!"
    else
        echo "Error: Notarization failed with status: $NOTARIZE_STATUS"
        echo "Check the output above for details"
        exit 1
    fi
fi

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo "App bundle: $APP_BUNDLE"
if [ -f "$DMG_PATH" ]; then
    echo "DMG file: $DMG_PATH"
    echo ""
    echo "To install, open the DMG and drag $APP_NAME.app to Applications"
else
    echo "DMG creation may have failed - check output above"
fi
