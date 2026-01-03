# Translator

A macOS translation app with text selection and screenshot translation.

## Features

| Feature | Description |
|---------|-------------|
| Text Translation | Select text + press `⌥T` to translate |
| Screenshot Translation | Capture screen region, OCR, and translate |
| Word Book | Save and manage translated words |
| Text-to-Speech | Pronounce words using system TTS |
| Import/Export | Export word book to CSV/JSON |

## Requirements

- macOS 15.0 (Sequoia) or later
- Apple Silicon or Intel Mac

## Installation

### From DMG (Recommended)

1. Download the latest `TranslatorApp-x.x.x.dmg` from [Releases](https://github.com/user/translator/releases)
2. Move `TranslatorApp.app` to `/Applications`
3. Grant necessary permissions:
   - **Screen Recording** - for screenshot translation
   - **Accessibility** - for text selection detection

### From Source

```bash
git clone https://github.com/user/translator.git
cd translator/TranslatorApp
xcodebuild -project TranslatorApp.xcodeproj -scheme TranslatorApp -configuration Release build
```

## Usage

### Text Translation

1. Select any text in any app (browser, editor, etc.)
2. Press `⌥T` (Option + T)
3. Translation popup appears near cursor
4. Click "收藏" to save to word book, click speaker icon to pronounce

### Screenshot Translation

1. Press `⌘ + ⇧ + S` (customizable)
2. Select a region on screen
3. Text is extracted via OCR and translated
4. Click "Save" to add to word book

### Word Book

- Open TranslatorApp to view saved words
- Search words by text or translation
- Export to CSV or JSON

## Tech Stack

| Component | Technology |
|-----------|------------|
| UI | SwiftUI |
| Storage | SwiftData |
| Translation | Apple Translation Framework |
| OCR | Vision Framework |
| Screen Capture | ScreenCaptureKit |
| TTS | AVSpeechSynthesizer |

## Privacy

- **No data leaves your device** - Translation uses Apple's on-device model
- **No tracking** - No analytics or telemetry
- **Local storage only** - Word book stored in local SwiftData database

## License

[MIT License](LICENSE)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
