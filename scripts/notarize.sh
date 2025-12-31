#!/bin/bash
set -e

# Notarization Script
# Submits app to Apple for notarization
#
# Prerequisites:
# 1. App must be signed with Developer ID certificate
# 2. Create app-specific password at appleid.apple.com
# 3. Store credentials in Keychain (see setup below)
#
# Setup credentials (run once):
#   xcrun notarytool store-credentials "notarytool-profile" \
#       --apple-id "your@email.com" \
#       --team-id "TEAM_ID" \
#       --password "app-specific-password"
#
# Usage: ./scripts/notarize.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_PATH="$PROJECT_ROOT/build/Release/TranslatorApp.app"
ZIP_PATH="$PROJECT_ROOT/build/TranslatorApp.zip"

# Keychain profile name (created with store-credentials)
PROFILE_NAME="${1:-notarytool-profile}"

echo "=== Notarizing TranslatorApp ==="
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    echo "Run ./scripts/build-release.sh and ./scripts/sign-app.sh first"
    exit 1
fi

# Create zip for notarization
echo "Creating zip archive..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# Submit for notarization
echo "Submitting to Apple for notarization..."
echo "This may take several minutes..."
xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$PROFILE_NAME" \
    --wait

# Staple the notarization ticket to the app
echo ""
echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"

# Verify
echo ""
echo "Verifying notarization..."
spctl --assess --type execute --verbose "$APP_PATH"

# Cleanup
rm -f "$ZIP_PATH"

echo ""
echo "=== Notarization Complete ==="
echo ""
echo "Next step: ./scripts/create-dmg.sh"
