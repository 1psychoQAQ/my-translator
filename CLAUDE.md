# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A personal translation toolkit consisting of three interconnected components:
- **macOS App** (TranslatorApp): Screenshot translation, word book, native messaging host
- **Chrome Extension** (ChromeExtension): Immersive web page translation, video subtitle translation
- **Flutter App** (translator_flutter): Cross-platform word book with cloud sync

## Architecture

```
Chrome Extension ──Native Messaging──▶ macOS App ──Firebase──▶ Flutter App
     │                                     │                        │
     ├─ Immersive translation              ├─ Translation engine    ├─ Word book
     └─ Video subtitles                    ├─ OCR (Vision)          └─ Cloud sync
                                           ├─ Screenshot capture
                                           └─ Word book (SwiftData)
```

Data flows: Chrome extension sends translation requests to macOS app via Native Messaging. macOS app uses Apple Translation Framework. Word book syncs across all platforms via Firebase Firestore.

## Development Commands

### macOS App
```bash
# Build and run
xcodebuild -project TranslatorApp/TranslatorApp.xcodeproj -scheme TranslatorApp build
open TranslatorApp/TranslatorApp.xcodeproj  # Open in Xcode

# Run tests
xcodebuild test -project TranslatorApp/TranslatorApp.xcodeproj -scheme TranslatorApp
```

### Chrome Extension
```bash
cd ChromeExtension
npm install
npm run build      # Build for production
npm run dev        # Development with watch
npm run test       # Run Vitest tests
npm run lint       # ESLint check
```

### Flutter App
```bash
cd translator_flutter
flutter pub get
flutter run                    # Run on connected device
flutter test                   # Run all tests
flutter test test/path.dart    # Run single test file
flutter analyze                # Static analysis
flutter pub run build_runner build  # Generate mocks for testing
```

## Technical Stack

| Platform | UI | Storage | Key Frameworks |
|----------|-----|---------|----------------|
| macOS | SwiftUI | SwiftData | Translation Framework, Vision, ScreenCaptureKit |
| Chrome | DOM injection | - | Manifest V3, Native Messaging API |
| Flutter | Material | Firebase Firestore | Riverpod, freezed |

## Core Design Patterns

### Dependency Injection
- **macOS**: Protocol + constructor injection (`init(service: ServiceProtocol)`)
- **Chrome**: Interface + factory functions (`createTranslator(messenger)`)
- **Flutter**: Riverpod providers (`ref.watch(serviceProvider)`)

### Error Handling
- All errors must be explicit; no silent failures
- **macOS**: `throws` + custom `TranslatorError` enum
- **Chrome**: `TranslatorError` class with `ErrorCode` enum
- **Flutter**: `Result<T>` sealed class (Success/Failure)

### Module Responsibilities
Each service does one thing only:
- Translation: `translate(text) → String`
- OCR: `extractText(image) → String`
- Storage: `save(word)` / `fetch()`
- Sync: `upload()` / `download()`

## Data Model (Word)

Shared across all platforms:
```
Word {
  id: UUID/String
  text: String
  translation: String
  source: "webpage" | "video" | "screenshot"
  sourceURL?: String
  tags: [String]
  createdAt: Date
  syncedAt?: Date
}
```

## Key Files

- `mind.md` - Core objectives and features
- `plan.md` - Development phases and task breakdown
- `plan-macos.md` - macOS detailed implementation plan
- `plan-chrome.md` - Chrome extension detailed implementation plan
- `plan-flutter.md` - Flutter detailed implementation plan
- `validate.md` - Cross-platform engineering principles
- `validate-macos.md` - macOS acceptance criteria and protocols
- `validate-chrome.md` - Chrome extension acceptance criteria
- `validate-flutter.md` - Flutter acceptance criteria

## Development Phases

1. **Phase 1**: macOS screenshot translation + local word book
2. **Phase 2**: Chrome immersive translation + word collection via Native Messaging
3. **Phase 3**: Video subtitle translation (YouTube, Bilibili)
4. **Phase 4**: Flutter app + Firebase cloud sync
