#!/bin/bash

# Generate PNG icons from SVG for FIL(L)M extension
# Requires: rsvg-convert (librsvg) or ImageMagick

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SVG_FILE="$PROJECT_ROOT/src/chrome/public/icons/icon.svg"
CHROME_ICONS="$PROJECT_ROOT/src/chrome/public/icons"
SAFARI_ICONS="$PROJECT_ROOT/src/safari/public/icons"

echo "Generating icons from SVG..."

# Chrome icon sizes
CHROME_SIZES=(16 32 48 128)

# Safari icon sizes
SAFARI_SIZES=(16 32 48 64 96 128 256 512 1024)

# Function to generate PNG from SVG
generate_icon() {
    local size=$1
    local output=$2

    if command -v rsvg-convert &> /dev/null; then
        rsvg-convert -w "$size" -h "$size" "$SVG_FILE" -o "$output"
    elif command -v convert &> /dev/null; then
        convert -background none -resize "${size}x${size}" "$SVG_FILE" "$output"
    else
        echo "Error: Neither rsvg-convert nor ImageMagick's convert found."
        echo "Please install librsvg or ImageMagick to generate icons."
        echo ""
        echo "On macOS: brew install librsvg"
        echo "On Ubuntu: sudo apt-get install librsvg2-bin"
        exit 1
    fi
}

# Generate Chrome icons
echo "Generating Chrome icons..."
for size in "${CHROME_SIZES[@]}"; do
    generate_icon "$size" "$CHROME_ICONS/icon${size}.png"
    echo "  Created icon${size}.png"
done

# Generate Safari icons
echo "Generating Safari icons..."
for size in "${SAFARI_SIZES[@]}"; do
    generate_icon "$size" "$SAFARI_ICONS/icon${size}.png"
    echo "  Created icon${size}.png"
done

echo ""
echo "Icons generated successfully!"
echo ""
echo "Note: For Safari, you'll also need to add these icons to the"
echo "Assets.xcassets in the Xcode project."
