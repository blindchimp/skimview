#!/bin/bash
# Convert icon.png to icon.icns for macOS app icon

set -e

if [ ! -f "icon.png" ]; then
    echo "Error: icon.png not found"
    exit 1
fi

# Create icon directory structure
mkdir -p icon.iconset

# Convert PNG to various required sizes for .icns
convert icon.png -resize 512x512 icon.iconset/icon_512x512.png
convert icon.png -resize 256x256 icon.iconset/icon_256x256.png
convert icon.png -resize 128x128 icon.iconset/icon_128x128.png
convert icon.png -resize 64x64 icon.iconset/icon_64x64.png
convert icon.png -resize 32x32 icon.iconset/icon_32x32.png
convert icon.png -resize 16x16 icon.iconset/icon_16x16.png

# Create the .icns file
iconutil -c icns icon.iconset -o icon.icns

# Clean up the iconset directory
rm -rf icon.iconset

echo "icon.icns created successfully"
