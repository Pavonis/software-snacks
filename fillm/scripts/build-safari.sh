#!/bin/bash

# Build script for FIL(L)M Safari extension
# This script builds the web extension and copies it to the Xcode project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SAFARI_DIR="$PROJECT_ROOT/src/safari"
XCODE_DIR="$SAFARI_DIR/xcode"
EXTENSION_RESOURCES="$XCODE_DIR/FillM Extension/Resources"

echo "Building FIL(L)M Safari extension..."

# Build the Safari extension
cd "$PROJECT_ROOT"
npm run build:safari

# Create Resources directory if it doesn't exist
mkdir -p "$EXTENSION_RESOURCES"

# Copy built files to Xcode project
echo "Copying built files to Xcode project..."
cp -r "$PROJECT_ROOT/dist/safari/"* "$EXTENSION_RESOURCES/"

# Copy manifest
cp "$SAFARI_DIR/manifest.json" "$EXTENSION_RESOURCES/"

# Create _locales if needed (Safari requires this)
mkdir -p "$EXTENSION_RESOURCES/_locales/en"
cat > "$EXTENSION_RESOURCES/_locales/en/messages.json" << 'EOF'
{
  "extension_name": {
    "message": "FIL(L)M - Fix It, LLM",
    "description": "Extension name"
  },
  "extension_description": {
    "message": "Capture web page issues and send them to Claude for analysis",
    "description": "Extension description"
  }
}
EOF

echo "Safari extension built successfully!"
echo ""
echo "Next steps:"
echo "1. Open $XCODE_DIR/FillM.xcodeproj in Xcode"
echo "2. Select your development team for code signing"
echo "3. Build and run the project"
echo "4. Enable the extension in Safari Preferences → Extensions"
