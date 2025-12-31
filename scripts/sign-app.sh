#!/bin/bash
set -e

# Code Signing Script
# Requires: Apple Developer ID certificate installed in Keychain
#
# Prerequisites:
# 1. Enroll in Apple Developer Program ($99/year)
# 2. Create "Developer ID Application" certificate in Developer Portal
# 3. Download and install certificate in Keychain Access
#
# Usage: ./scripts/sign-app.sh [DEVELOPER_ID]
#
# Example: ./scripts/sign-app.sh "Developer ID Application: Your Name (TEAM_ID)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_PATH="$PROJECT_ROOT/build/Release/TranslatorApp.app"
NATIVE_HOST_PATH="$APP_PATH/Contents/MacOS/NativeMessagingHost"

# Developer ID (pass as argument or set here)
DEVELOPER_ID="${1:-Developer ID Application: Your Name (TEAM_ID)}"

echo "=== Signing TranslatorApp ==="
echo "Developer ID: $DEVELOPER_ID"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    echo "Run ./scripts/build-release.sh first"
    exit 1
fi

# Sign NativeMessagingHost first (if exists)
if [ -f "$NATIVE_HOST_PATH" ]; then
    echo "Signing NativeMessagingHost..."
    codesign --force --options runtime \
        --sign "$DEVELOPER_ID" \
        --timestamp \
        "$NATIVE_HOST_PATH"
fi

# Sign the main app (deep signs all nested code)
echo "Signing TranslatorApp.app..."
codesign --force --deep --options runtime \
    --sign "$DEVELOPER_ID" \
    --timestamp \
    "$APP_PATH"

# Verify signature
echo ""
echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo ""
echo "=== Signing Complete ==="
echo ""
echo "Next step: ./scripts/notarize.sh"
