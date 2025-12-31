# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A personal translation toolkit consisting of two interconnected components:
- **macOS App** (TranslatorApp): Screenshot translation, word book, native messaging host
- **Chrome Extension** (ChromeExtension): Web page word translation, word collection

## Architecture

```
Chrome Extension ──Native Messaging──▶ NativeMessagingHost ──SwiftData──▶ TranslatorApp
     │                                        │
     ├─ 划词翻译                               ├─ Apple Translation Framework
     └─ 单词收藏                               ├─ AVSpeechSynthesizer (发音)
                                              └─ SwiftData (共享数据库)
```

Data flows: Chrome extension sends translation/speak/save requests to NativeMessagingHost via Native Messaging. NativeMessagingHost uses Apple Translation Framework for translation and AVSpeechSynthesizer for TTS. Word book data is stored in SwiftData and shared with TranslatorApp.

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
npm run typecheck  # TypeScript check
```

### NativeMessagingHost
```bash
cd TranslatorApp/NativeMessagingHost
swift build           # Build
swift build -c release  # Release build
```

## Technical Stack

| Platform | UI | Storage | Key Frameworks |
|----------|-----|---------|----------------|
| macOS | SwiftUI | SwiftData | Translation Framework, Vision, ScreenCaptureKit, AVFoundation |
| Chrome | DOM injection | - | Manifest V3, Native Messaging API |

## Core Design Patterns

### Dependency Injection
- **macOS**: Protocol + constructor injection (`init(service: ServiceProtocol)`)
- **Chrome**: Interface + factory functions (`createTranslator(messenger)`)

### Error Handling
- All errors must be explicit; no silent failures
- **macOS**: `throws` + custom `TranslatorError` enum
- **Chrome**: `TranslatorError` class with `ErrorCode` enum

### Module Responsibilities
Each service does one thing only:
- Translation: `translate(text) → String`
- OCR: `extractText(image) → String`
- Storage: `save(word)` / `fetch()`
- Speech: `speak(text)`

## Data Model (Word)

Shared between NativeMessagingHost and TranslatorApp:
```
Word {
  id: UUID/String
  text: String
  translation: String
  source: "webpage" | "screenshot"
  sourceURL?: String
  sentence?: String    // 上下文句子
  tags: [String]
  createdAt: Date
  syncedAt?: Date
}
```

## Native Messaging Actions

| Action | Description |
|--------|-------------|
| `translate` | Translate text with optional context |
| `saveWord` | Save word to SwiftData |
| `speak` | Text-to-speech via AVSpeechSynthesizer |
| `ping` | Health check |

## Key Files

- `mind.md` - Core objectives and features
- `plan.md` - Development phases and task breakdown
- `plan-macos.md` - macOS detailed implementation plan
- `plan-chrome.md` - Chrome extension detailed implementation plan
- `validate.md` - Cross-platform engineering principles
- `validate-macos.md` - macOS acceptance criteria
- `validate-chrome.md` - Chrome extension acceptance criteria

## Project Structure

```
my-translator/
├── TranslatorApp/              # macOS App
│   ├── TranslatorApp/          # Main app (截图翻译 + 单词本)
│   ├── NativeMessagingHost/    # Chrome 通信服务
│   └── TranslatorAppTests/
├── ChromeExtension/            # Chrome 扩展
│   ├── src/                    # TypeScript 源码
│   ├── tests/                  # Vitest 测试
│   └── dist/                   # 构建输出
└── docs/                       # 文档
```
