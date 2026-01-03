# Privacy Policy

**Last updated: December 2024**

## Overview

Translator is a privacy-first translation extension. We do not collect, store, or transmit any personal data to external servers.

## Data Collection

### What We Collect

**Nothing.** We 了do not collect any personal information.

### What Stays on Your Device

- **Selected text**: Text you select for translation is processed entirely on your device using Apple's on-device Translation Framework
- **Word book**: Saved words are stored locally in SwiftData on your Mac
- **Preferences**: Extension settings are stored in Chrome's local storage

## Data Processing

### Translation

All translation is performed **on-device** using Apple's Translation Framework (macOS 15.0+). No text is ever sent to external translation services.

### Native Messaging

The extension communicates with a local macOS companion app via Chrome's Native Messaging API. This communication:
- Happens entirely on your local machine
- Never leaves your device
- Is not logged or stored

## Third-Party Services

**We use no third-party services.**

- No analytics
- No tracking
- No advertising
- No cloud storage
- No external APIs

## Permissions Explained

| Permission | Purpose |
|------------|---------|
| `nativeMessaging` | Communicate with local macOS app for translation |
| `activeTab` | Access selected text on current page |
| `storage` | Store extension preferences locally |
| `<all_urls>` | Enable translation on any webpage |

## Data Sharing

We do not share any data with anyone because we do not collect any data.

## Data Retention

Since we don't collect data, there is nothing to retain. Your word book is stored locally on your device and can be deleted at any time by removing the TranslatorApp.

## Children's Privacy

Our extension does not collect any personal information from anyone, including children.

## Changes to This Policy

We may update this privacy policy from time to time. Any changes will be posted in the extension's GitHub repository.

## Contact

For questions about this privacy policy, please open an issue on our GitHub repository.

## Open Source

This extension is open source. You can review the complete source code to verify our privacy practices:
- GitHub: https://github.com/user/translator
