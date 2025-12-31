# Installation Guide

## macOS App Installation

### From DMG (Recommended)

1. Download the latest `TranslatorApp-x.x.x.dmg` from [Releases](https://github.com/user/my-translator/releases)
2. Open the DMG file
3. Drag `TranslatorApp.app` to the Applications folder
4. Launch TranslatorApp from Applications
5. Grant necessary permissions when prompted:
   - Screen Recording (for screenshot translation)
   - Accessibility (for global shortcuts)

### From Source

```bash
# Clone repository
git clone https://github.com/user/my-translator.git
cd my-translator

# Build macOS app
cd TranslatorApp
xcodebuild -project TranslatorApp.xcodeproj \
    -scheme TranslatorApp \
    -configuration Release \
    build

# Build NativeMessagingHost
cd NativeMessagingHost
swift build -c release
```

## Chrome Extension Installation

### From Chrome Web Store (Recommended)

1. Visit [Translator Extension](https://chrome.google.com/webstore/detail/translator/xxx) in Chrome Web Store
2. Click "Add to Chrome"
3. Follow the prompts to install

### From Source (Developer Mode)

1. Build the extension:
   ```bash
   cd ChromeExtension
   npm install
   npm run build
   ```

2. Open Chrome and navigate to `chrome://extensions/`

3. Enable "Developer mode" (toggle in top right)

4. Click "Load unpacked" and select the `ChromeExtension/dist` folder

## Native Messaging Setup

For the Chrome extension to communicate with the macOS app, you need to register the Native Messaging host.

### Automatic Setup

Launch TranslatorApp once - it will automatically register the native messaging host.

### Manual Setup

1. Create the manifest directory:
   ```bash
   mkdir -p ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts
   ```

2. Create the manifest file `com.translator.nativemessaginghost.json`:
   ```json
   {
     "name": "com.translator.nativemessaginghost",
     "description": "Translator Native Messaging Host",
     "path": "/Applications/TranslatorApp.app/Contents/MacOS/NativeMessagingHost",
     "type": "stdio",
     "allowed_origins": [
       "chrome-extension://YOUR_EXTENSION_ID/"
     ]
   }
   ```

3. Replace `YOUR_EXTENSION_ID` with your extension's ID (found in `chrome://extensions/`)

## System Requirements

### macOS App
- macOS 15.0 (Sequoia) or later
- Apple Silicon or Intel Mac

### Chrome Extension
- Google Chrome 88 or later
- Chromium-based browsers (Edge, Brave, etc.)

## Troubleshooting

### "App is damaged and can't be opened"

If you see this error when opening the app:

```bash
xattr -cr /Applications/TranslatorApp.app
```

### Extension can't connect to native app

1. Verify NativeMessagingHost is installed:
   ```bash
   ls ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/
   ```

2. Check the manifest file exists and has correct permissions

3. Ensure the extension ID in the manifest matches your installed extension

### Translation not working

1. Make sure TranslatorApp is running
2. Check that macOS has an active internet connection
3. Verify the Apple Translation Framework is available (macOS 15.0+)

## Uninstallation

### macOS App

1. Quit TranslatorApp
2. Move `/Applications/TranslatorApp.app` to Trash
3. Remove native messaging host:
   ```bash
   rm ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/com.translator.nativemessaginghost.json
   ```
4. (Optional) Remove app data:
   ```bash
   rm -rf ~/Library/Application\ Support/com.translator.app
   ```

### Chrome Extension

1. Go to `chrome://extensions/`
2. Find "Translator" and click "Remove"
