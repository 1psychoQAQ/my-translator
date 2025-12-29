#!/bin/bash
#
# Install Native Messaging Host for development
# Uses the local build directory instead of /Applications
#
# Usage:
#   ./install-dev.sh <extension-id>
#

set -e

# Configuration
HOST_NAME="com.liujiahao.translator"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Host executable path (from build directory)
HOST_PATH="$SCRIPT_DIR/.build/release/NativeMessagingHost"

# Check if release build exists, fall back to debug
if [ ! -f "$HOST_PATH" ]; then
    HOST_PATH="$SCRIPT_DIR/.build/debug/NativeMessagingHost"
fi

# Chrome Native Messaging directory
CHROME_NM_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "  Native Messaging Host DEV Installer"
echo "========================================"
echo ""

# Check for extension ID argument
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: $0 <extension-id>${NC}"
    echo ""
    echo "To find your extension ID:"
    echo "1. Open Chrome and go to chrome://extensions"
    echo "2. Enable 'Developer mode'"
    echo "3. Load unpacked extension from ChromeExtension/dist"
    echo "4. Copy the generated extension ID"
    echo ""
    exit 1
fi

EXTENSION_ID="$1"

# Check if host executable exists
if [ ! -f "$HOST_PATH" ]; then
    echo -e "${RED}Error: Host executable not found${NC}"
    echo "Please build first:"
    echo "  cd $SCRIPT_DIR && swift build"
    exit 1
fi

# Make executable
chmod +x "$HOST_PATH"

# Create manifest directory
mkdir -p "$CHROME_NM_DIR"

# Create manifest
cat > "$CHROME_NM_DIR/$HOST_NAME.json" << EOF
{
  "name": "$HOST_NAME",
  "description": "Native Messaging Host for Translator App (DEV)",
  "path": "$HOST_PATH",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$EXTENSION_ID/"
  ]
}
EOF

echo -e "${GREEN}Installed manifest:${NC}"
echo "  $CHROME_NM_DIR/$HOST_NAME.json"
echo ""
echo -e "${GREEN}Host executable:${NC}"
echo "  $HOST_PATH"
echo ""
echo -e "${GREEN}Extension ID:${NC}"
echo "  $EXTENSION_ID"
echo ""
echo "========================================"
echo -e "${GREEN}Installation Complete!${NC}"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Restart Chrome completely (quit and reopen)"
echo "2. Test the extension"
echo ""
