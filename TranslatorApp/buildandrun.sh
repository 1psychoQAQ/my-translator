#!/bin/bash
set -e

APP_NAME="TranslatorApp"
BUILD_DIR="$(pwd)/build"
APP="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"

echo "▶ Build"
xcodebuild \
  -scheme "$APP_NAME" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  build

echo "▶ Codesign"
codesign --force --deep --sign - "$APP"

echo "▶ Kill old process"
killall "$APP_NAME" 2>/dev/null || true

echo "▶ Run"
"$APP/Contents/MacOS/$APP_NAME"
