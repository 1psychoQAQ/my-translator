# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A macOS translation app with the following features:
- **Screenshot Translation**: Capture screen area, OCR text, translate
- **Text Translation**: Select text + press ⌥T to translate
- **Word Book**: Save and manage translated words

## Architecture

```
TranslatorApp (macOS)
├── Screenshot Translation
│   ├── ScreenCaptureKit (screen capture)
│   ├── Vision Framework (OCR)
│   └── Apple Translation Framework
│
├── Text Translation (⌥T hotkey)
│   ├── Clipboard (simulates Cmd+C to copy selected text)
│   ├── Translation Popup (floating window)
│   └── Apple Translation Framework
│
└── Word Book
    ├── SwiftData (storage)
    └── Import/Export (CSV, JSON)
```

## Development Commands

### macOS App
```bash
# Build and run
xcodebuild -project TranslatorApp/TranslatorApp.xcodeproj -scheme TranslatorApp build
open TranslatorApp/TranslatorApp.xcodeproj  # Open in Xcode

# Run tests
xcodebuild test -project TranslatorApp/TranslatorApp.xcodeproj -scheme TranslatorApp
```

## Technical Stack

| Component | Technology |
|-----------|------------|
| UI | SwiftUI |
| Storage | SwiftData |
| Translation | Apple Translation Framework |
| OCR | Vision Framework |
| Screen Capture | ScreenCaptureKit |
| Hotkeys | Carbon Event API |
| TTS | AVSpeechSynthesizer |

## Core Design Patterns

### Dependency Injection
Protocol + constructor injection (`init(service: ServiceProtocol)`)

### Error Handling
- All errors must be explicit; no silent failures
- `throws` + custom `TranslatorError` enum

### Module Responsibilities
Each service does one thing only:
- Translation: `translate(text) → String`
- OCR: `extractText(image) → String`
- Storage: `save(word)` / `fetch()`
- Speech: `speak(text)`

## Data Model (Word)

```swift
Word {
  id: UUID
  text: String
  translation: String
  source: "selection" | "screenshot"
  sentence?: String    // context sentence
  tags: [String]
  createdAt: Date
}
```

## Key Components

### TranslationPopupController
Shows floating translation popup:
- Uses NSPanel with `.floating` level
- Appears near mouse cursor
- Auto-dismisses when clicking outside

### TranslationService
Wrapper around Apple Translation Framework:
- Uses `.translationTask` SwiftUI modifier
- Caches translation session for reuse

## Project Structure

```
my-translator/
├── TranslatorApp/
│   ├── TranslatorApp/
│   │   ├── App/                    # App entry, AppState
│   │   ├── Core/
│   │   │   ├── Managers/           # WordBookManager
│   │   │   └── Services/           # TranslationService
│   │   └── Features/
│   │       ├── ScreenshotTranslate/  # Screenshot translation
│   │       ├── TextSelection/        # Translation popup (⌥T)
│   │       ├── WordBook/             # Word book UI
│   │       └── Onboarding/           # Permissions guide
│   └── TranslatorAppTests/
└── docs/
```

## Required Permissions

The app requires:
1. **Screen Recording** - For screenshot translation
