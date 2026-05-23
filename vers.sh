#!/bin/bash
set -e

BASE_VERSION=$(cat VERSION)
BUILD=$(git rev-list --count HEAD)
SHA=$(git rev-parse --short HEAD)

VERSION="$BASE_VERSION+$BUILD"

echo "Building $VERSION ($SHA)"
echo "MyApp-$BASE_VERSION-$BUILD.dmg" 
exit 0

# update plist
/usr/libexec/PlistBuddy -c \
"Set :CFBundleShortVersionString $BASE_VERSION" \
MyApp.app/Contents/Info.plist

/usr/libexec/PlistBuddy -c \
"Set :CFBundleVersion $BUILD" \
MyApp.app/Contents/Info.plist

# build dmg
create-dmg \
"MyApp-$BASE_VERSION-$BUILD.dmg" \
MyApp.app
