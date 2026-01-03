# Installation Guide

## From DMG (Recommended)

1. Download the latest `TranslatorApp-x.x.x.dmg` from [Releases](https://github.com/user/my-translator/releases)
2. Open the DMG file
3. Drag `TranslatorApp.app` to the Applications folder
4. Launch TranslatorApp from Applications
5. Grant necessary permissions when prompted:
   - **Screen Recording** - for screenshot translation
   - **Accessibility** - for detecting text selection in other apps

## From Source

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
```

## System Requirements

- macOS 15.0 (Sequoia) or later
- Apple Silicon or Intel Mac

## Permissions

The app requires two permissions to function properly:

### Screen Recording
Required for screenshot translation. Allows the app to capture screen content.

### Accessibility
Required for text selection translation. Allows the app to detect when you select text in other applications.

## Troubleshooting

### "App is damaged and can't be opened"

If you see this error when opening the app:

```bash
xattr -cr /Applications/TranslatorApp.app
```

### Translation not working

1. Make sure you're running macOS 15.0 or later
2. Check that macOS has an active internet connection (for downloading language models)
3. Verify the Apple Translation Framework is available

### Text selection not detected

1. Make sure Accessibility permission is granted in System Settings > Privacy & Security > Accessibility
2. Try restarting the app after granting permission

## Uninstallation

1. Quit TranslatorApp
2. Move `/Applications/TranslatorApp.app` to Trash
3. (Optional) Remove app data:
   ```bash
   rm -rf ~/Library/Application\ Support/com.translator.app
   rm -rf ~/Library/Containers/com.translator.app
   ```
