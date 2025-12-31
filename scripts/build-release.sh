#!/bin/bash
set -e

# Build Release Script for TranslatorApp
# Usage: ./scripts/build-release.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_NAME="TranslatorApp"
BUILD_DIR="$PROJECT_ROOT/build"
RELEASE_DIR="$BUILD_DIR/Release"

echo "=== Building $APP_NAME Release ==="

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build TranslatorApp
echo "Building TranslatorApp..."
cd "$PROJECT_ROOT/TranslatorApp"
xcodebuild -project TranslatorApp.xcodeproj \
    -scheme TranslatorApp \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive

# Export app from archive
echo "Exporting app..."
xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -exportOptionsPlist "$SCRIPT_DIR/export-options.plist" \
    -exportPath "$RELEASE_DIR"

# Build NativeMessagingHost
echo "Building NativeMessagingHost..."
cd "$PROJECT_ROOT/TranslatorApp/NativeMessagingHost"
swift build -c release

# Copy NativeMessagingHost to app bundle
NATIVE_HOST_SRC="$PROJECT_ROOT/TranslatorApp/NativeMessagingHost/.build/release/NativeMessagingHost"
NATIVE_HOST_DST="$RELEASE_DIR/$APP_NAME.app/Contents/MacOS/NativeMessagingHost"

if [ -f "$NATIVE_HOST_SRC" ]; then
    echo "Copying NativeMessagingHost to app bundle..."
    cp "$NATIVE_HOST_SRC" "$NATIVE_HOST_DST"
fi

echo ""
echo "=== Build Complete ==="
echo "App location: $RELEASE_DIR/$APP_NAME.app"
echo ""
echo "Next steps:"
echo "1. Sign the app: ./scripts/sign-app.sh"
echo "2. Notarize: ./scripts/notarize.sh"
echo "3. Create DMG: ./scripts/create-dmg.sh"
