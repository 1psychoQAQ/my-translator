#!/bin/bash
#
# Install Native Messaging Host for Chrome/Chromium
#
# Usage:
#   ./install-native-host.sh <extension-id>
#
# Example:
#   ./install-native-host.sh abcdefghijklmnopqrstuvwxyz123456
#

set -e

# Configuration
HOST_NAME="com.liujiahao.translator"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST_TEMPLATE="$SCRIPT_DIR/$HOST_NAME.json"

# Host executable path (in app bundle)
HOST_PATH="/Applications/TranslatorApp.app/Contents/MacOS/NativeMessagingHost"

# Chrome Native Messaging directory
CHROME_NM_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
CHROMIUM_NM_DIR="$HOME/Library/Application Support/Chromium/NativeMessagingHosts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "  Native Messaging Host Installer"
echo "========================================"
echo ""

# Check for extension ID argument
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: $0 <extension-id>${NC}"
    echo ""
    echo "To find your extension ID:"
    echo "1. Open Chrome and go to chrome://extensions"
    echo "2. Enable 'Developer mode'"
    echo "3. Find your extension and copy its ID"
    echo ""
    echo -e "${YELLOW}Example:${NC}"
    echo "  $0 abcdefghijklmnopqrstuvwxyz123456"
    exit 1
fi

EXTENSION_ID="$1"

# Validate extension ID format (32 lowercase letters)
if ! [[ "$EXTENSION_ID" =~ ^[a-z]{32}$ ]]; then
    echo -e "${YELLOW}Warning: Extension ID format looks unusual.${NC}"
    echo "Expected: 32 lowercase letters"
    echo "Got: $EXTENSION_ID"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if host executable exists
if [ ! -f "$HOST_PATH" ]; then
    echo -e "${RED}Error: Host executable not found at $HOST_PATH${NC}"
    echo ""
    echo "Please build and install TranslatorApp first:"
    echo "1. Open TranslatorApp.xcodeproj in Xcode"
    echo "2. Build the NativeMessagingHost target"
    echo "3. Archive and export to /Applications"
    exit 1
fi

# Create manifest with the actual extension ID
create_manifest() {
    local output_path="$1"
    mkdir -p "$(dirname "$output_path")"

    cat > "$output_path" << EOF
{
  "name": "$HOST_NAME",
  "description": "Native Messaging Host for Translator App",
  "path": "$HOST_PATH",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$EXTENSION_ID/"
  ]
}
EOF
    echo -e "${GREEN}Created: $output_path${NC}"
}

# Install for Chrome
echo "Installing for Google Chrome..."
create_manifest "$CHROME_NM_DIR/$HOST_NAME.json"

# Install for Chromium (if directory exists)
if [ -d "$HOME/Library/Application Support/Chromium" ]; then
    echo "Installing for Chromium..."
    create_manifest "$CHROMIUM_NM_DIR/$HOST_NAME.json"
fi

echo ""
echo -e "${GREEN}========================================"
echo "  Installation Complete!"
echo "========================================${NC}"
echo ""
echo "Host Name: $HOST_NAME"
echo "Extension ID: $EXTENSION_ID"
echo ""
echo "Next steps:"
echo "1. Restart Chrome"
echo "2. Test the connection from your extension"
echo ""
