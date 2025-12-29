# Native Messaging Host

Chrome Native Messaging Host for TranslatorApp.

## Overview

This is a command-line tool that receives messages from the Chrome extension via stdin and sends responses via stdout. It uses:

- **Apple Translation Framework** (macOS 15+) for text translation
- **SwiftData** for word book storage (shared with main app)

## Build

### Option 1: Using Swift Package Manager (Standalone)

```bash
cd TranslatorApp/NativeMessagingHost
swift build -c release
```

The binary will be at `.build/release/NativeMessagingHost`.

### Option 2: Add to Xcode Project

1. Open `TranslatorApp.xcodeproj` in Xcode
2. File → New → Target...
3. Select "macOS" → "Command Line Tool"
4. Name: `NativeMessagingHost`
5. Add the source files to the new target
6. Build Settings:
   - Deployment Target: macOS 14.0+
   - Product Name: `NativeMessagingHost`

## Install

### 1. Build the executable

```bash
swift build -c release
```

### 2. Copy to Applications

Copy the binary to the main app bundle:

```bash
cp .build/release/NativeMessagingHost /Applications/TranslatorApp.app/Contents/MacOS/
```

Or for development, update the manifest path to point to the build location.

### 3. Install Native Messaging manifest

```bash
# Get your extension ID from chrome://extensions
./install-native-host.sh <your-extension-id>
```

Example:
```bash
./install-native-host.sh abcdefghijklmnopabcdefghijklmnop
```

### 4. Restart Chrome

Close and reopen Chrome for the changes to take effect.

## Message Protocol

### Request Format

```json
{
  "action": "translate" | "saveWord" | "ping",
  "payload": { ... }
}
```

### Translate Request

```json
{
  "action": "translate",
  "payload": {
    "text": "Hello, World!",
    "sourceLanguage": "en",
    "targetLanguage": "zh-Hans"
  }
}
```

### Translate Response

```json
{
  "success": true,
  "translation": "你好，世界！"
}
```

### Save Word Request

```json
{
  "action": "saveWord",
  "payload": {
    "id": "uuid-string",
    "text": "hello",
    "translation": "你好",
    "source": "webpage",
    "sourceURL": "https://example.com",
    "tags": [],
    "createdAt": 1703836800000
  }
}
```

### Save Word Response

```json
{
  "success": true
}
```

### Ping Request/Response

```json
// Request
{ "action": "ping", "payload": {} }

// Response
{ "success": true, "version": "1.0.0" }
```

## Troubleshooting

### Check if host is registered

```bash
cat ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/com.liujiahao.translator.json
```

### Test the host manually

```bash
# Create a test message (ping)
echo '{"action":"ping","payload":{}}' | python3 -c "
import sys
import struct
msg = sys.stdin.read().encode()
sys.stdout.buffer.write(struct.pack('<I', len(msg)) + msg)
" | /Applications/TranslatorApp.app/Contents/MacOS/NativeMessagingHost
```

### Check Chrome extension console

1. Open `chrome://extensions`
2. Find your extension and click "Inspect views: service worker"
3. Look for connection errors in the console

## Files

- `main.swift` - Entry point, handles stdin/stdout protocol
- `MessageHandler.swift` - Routes messages to appropriate handlers
- `HostTranslationService.swift` - Translation using Apple Translation Framework
- `HostWordBookService.swift` - Word storage using SwiftData
- `com.liujiahao.translator.json` - Native Messaging manifest template
- `install-native-host.sh` - Installation script
