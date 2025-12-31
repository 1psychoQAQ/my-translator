#!/bin/bash
set -e

# DMG Creation Script
# Creates a distributable DMG file
#
# Usage: ./scripts/create-dmg.sh [VERSION]
#
# Example: ./scripts/create-dmg.sh 1.0.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_NAME="TranslatorApp"
APP_PATH="$PROJECT_ROOT/build/Release/$APP_NAME.app"
VERSION="${1:-1.0.0}"
DMG_NAME="${APP_NAME}-${VERSION}"
DMG_PATH="$PROJECT_ROOT/build/$DMG_NAME.dmg"
TEMP_DMG_PATH="$PROJECT_ROOT/build/${DMG_NAME}-temp.dmg"
VOLUME_NAME="$APP_NAME"

echo "=== Creating DMG ==="
echo "Version: $VERSION"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    echo "Run build and sign scripts first"
    exit 1
fi

# Remove old DMG if exists
rm -f "$DMG_PATH" "$TEMP_DMG_PATH"

# Create temporary directory for DMG contents
TEMP_DIR=$(mktemp -d)
echo "Preparing DMG contents..."

# Copy app to temp directory
cp -R "$APP_PATH" "$TEMP_DIR/"

# Create Applications symlink
ln -s /Applications "$TEMP_DIR/Applications"

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov -format UDRW \
    "$TEMP_DMG_PATH"

# Mount DMG for customization (optional - add background image, icon positions)
# echo "Mounting DMG for customization..."
# MOUNT_DIR=$(hdiutil attach -readwrite -noverify "$TEMP_DMG_PATH" | grep Volumes | cut -f3)
# ... customize ...
# hdiutil detach "$MOUNT_DIR"

# Convert to compressed read-only DMG
echo "Compressing DMG..."
hdiutil convert "$TEMP_DMG_PATH" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

# Cleanup
rm -rf "$TEMP_DIR"
rm -f "$TEMP_DMG_PATH"

# Get file size
SIZE=$(du -h "$DMG_PATH" | cut -f1)

echo ""
echo "=== DMG Created ==="
echo "Location: $DMG_PATH"
echo "Size: $SIZE"
echo ""
echo "Distribution checklist:"
echo "  [ ] Test on clean macOS install"
echo "  [ ] Upload to GitHub Releases"
echo "  [ ] Update README with download link"
