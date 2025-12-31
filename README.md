# Translator

A personal translation toolkit for macOS and Chrome. Zero-cost, privacy-first, powered by Apple's on-device translation.

## Features

| Feature | Platform | Description |
|---------|----------|-------------|
| Web Translation | Chrome | Select text on any webpage to translate with context |
| Word Collection | Chrome + macOS | Save words with sentence context to word book |
| Screenshot Translation | macOS | Capture screen region, OCR, and translate |
| Word Book | macOS | Review saved words with source links |
| Text-to-Speech | Both | Pronounce words using system TTS |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Chrome Extension                       │
│   - Text selection translation                          │
│   - Sentence context extraction                         │
│   - Word collection                                     │
└─────────────────────┬───────────────────────────────────┘
                      │ Native Messaging
┌─────────────────────▼───────────────────────────────────┐
│                 NativeMessagingHost                      │
│   - Apple Translation Framework                         │
│   - AVSpeechSynthesizer (TTS)                          │
│   - SwiftData (shared database)                        │
└─────────────────────┬───────────────────────────────────┘
                      │ SwiftData
┌─────────────────────▼───────────────────────────────────┐
│                   TranslatorApp                          │
│   - Screenshot capture (ScreenCaptureKit)              │
│   - OCR (Vision Framework)                             │
│   - Word Book UI                                       │
└─────────────────────────────────────────────────────────┘
```

## Requirements

- **macOS 15.0+** (Sequoia) - Required for Apple Translation Framework
- **Chrome / Edge / Brave** - Any Chromium-based browser

## Installation

### Option 1: Download Release (Recommended)

1. Download the latest release from [Releases](https://github.com/user/translator/releases)
2. Move `TranslatorApp.app` to `/Applications`
3. Install the Chrome extension from Chrome Web Store (coming soon)

### Option 2: Build from Source

See [Building from Source](#building-from-source) below.

## Building from Source

### Prerequisites

- Xcode 16.0+
- Node.js 18+
- Swift 6.0+

### macOS App

```bash
# Clone the repository
git clone https://github.com/user/translator.git
cd translator

# Build the app
cd TranslatorApp
xcodebuild -project TranslatorApp.xcodeproj -scheme TranslatorApp -configuration Release build

# Build Native Messaging Host
cd NativeMessagingHost
swift build -c release
```

### Chrome Extension

```bash
cd ChromeExtension

# Install dependencies
npm install

# Build for production
npm run build

# Run tests
npm run test
```

### Install Native Messaging Host

```bash
# Copy the manifest
cp com.translator.app.json ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/

# Update the path in the manifest to point to your built binary
```

## Usage

### Web Translation

1. Select any text on a webpage
2. A popup appears with the translation
3. Click "Save" to add to word book
4. Click the speaker icon to hear pronunciation

### Screenshot Translation

1. Press `⌘ + ⇧ + S` (customizable)
2. Select a region on screen
3. Text is extracted via OCR and translated
4. Click "Save" to add to word book

### Word Book

- Open TranslatorApp to view saved words
- Click "Open Original" to jump to the source webpage (uses Text Fragments)
- Search words by text or translation

## Development

### Chrome Extension

```bash
cd ChromeExtension
npm run dev        # Development with watch
npm run test       # Run tests
npm run lint       # ESLint check
npm run typecheck  # TypeScript check
```

### macOS App

```bash
# Run tests
xcodebuild test -project TranslatorApp/TranslatorApp.xcodeproj -scheme TranslatorApp

# Build Native Messaging Host
cd TranslatorApp/NativeMessagingHost
swift build
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| macOS UI | SwiftUI |
| Storage | SwiftData |
| Translation | Apple Translation Framework |
| OCR | Vision Framework |
| Screen Capture | ScreenCaptureKit |
| TTS | AVSpeechSynthesizer |
| Chrome Extension | TypeScript + Manifest V3 |
| Build Tool | Vite |
| Testing | Vitest (Chrome), XCTest (macOS) |

## Privacy

- **No data leaves your device** - Translation uses Apple's on-device model
- **No tracking** - No analytics or telemetry
- **Local storage only** - Word book stored in local SwiftData database

## License

[MIT License](LICENSE)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
