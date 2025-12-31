# 翻译工具开发计划

## 核心功能（来自 mind.md）

| # | 功能 | 平台 | 状态 |
|---|------|-----|------|
| 1 | 网页划词翻译 + 语境翻译 | Chrome 扩展 | ✅ 完成 |
| 2 | 单词收藏 + 句子上下文 | Chrome → macOS | ✅ 完成 |
| 3 | 截图翻译 + OCR | macOS | ✅ 完成 |
| 4 | 单词本 + 原文跳转 | macOS | ✅ 完成 |
| 5 | 系统发音 (TTS) | macOS + Chrome | ✅ 完成 |

---

## 技术方案

### macOS App

| 组件 | 技术 | 成本 |
|-----|------|-----|
| UI | SwiftUI | ¥0 |
| 存储 | SwiftData | ¥0 |
| 翻译 | Apple Translation Framework | ¥0 |
| OCR | Vision Framework | ¥0 |
| 截图 | ScreenCaptureKit | ¥0 |
| 发音 | AVSpeechSynthesizer | ¥0 |
| Chrome 通信 | Native Messaging Host | ¥0 |

### Chrome 扩展

| 组件 | 技术 | 成本 |
|-----|------|-----|
| 扩展规范 | Manifest V3 | ¥0 |
| 语言 | TypeScript | ¥0 |
| 构建 | Vite | ¥0 |
| 测试 | Vitest | ¥0 |

---

## 已完成阶段

### Phase 1: macOS 基础 ✅

- 截图翻译流程 (⌘+⇧+S → OCR → 翻译 → 悬浮窗)
- 本地单词本 (SwiftData CRUD)
- 单词本 UI (列表/搜索/删除)

### Phase 2: Chrome 扩展 ✅

- 划词翻译 + 语境提取
- Native Messaging 通信
- 单词收藏到 macOS

### Phase 3: 增强功能 ✅

- 句子上下文保存
- Text Fragment 原文跳转
- 系统发音 (TTS)

---

## 架构

```
┌─────────────────────────────────────────────────────────┐
│                  Chrome Extension                        │
│   - 划词翻译                                             │
│   - 句子提取                                             │
│   - 单词收藏                                             │
│   技术: TypeScript + Manifest V3                        │
└─────────────┬───────────────────────────────────────────┘
              │ Native Messaging
┌─────────────▼───────────────────────────────────────────┐
│                 NativeMessagingHost                      │
│   - 翻译服务 (Apple Translation)                        │
│   - 发音服务 (AVSpeechSynthesizer)                      │
│   - 单词存储 (SwiftData)                                │
│   技术: Swift                                           │
└─────────────┬───────────────────────────────────────────┘
              │ SwiftData (共享数据库)
┌─────────────▼───────────────────────────────────────────┐
│                   TranslatorApp                          │
│   - 截图翻译 (OCR + Translation)                        │
│   - 单词本 UI                                           │
│   - 发音                                                │
│   技术: SwiftUI + SwiftData                             │
└─────────────────────────────────────────────────────────┘
```

---

## 数据模型

### macOS (Swift)

```swift
@Model
class Word {
    var id: UUID
    var text: String
    var translation: String
    var source: String      // "webpage" | "screenshot"
    var sourceURL: String?
    var sentence: String?   // 上下文句子
    var tags: [String]
    var createdAt: Date
    var syncedAt: Date?
}
```

### Chrome (TypeScript)

```typescript
interface WordEntry {
  id: string;
  text: string;
  translation: string;
  source: 'webpage' | 'screenshot';
  sourceURL?: string;
  sentence?: string;
  tags: string[];
  createdAt: number;
  syncedAt?: number;
}
```

---

## 项目结构

```
my-translator/
├── mind.md                       # 核心目标
├── plan.md                       # 开发计划（本文件）
├── validate.md                   # 通用验收原则
├── validate-macos.md             # macOS 验收规范
├── validate-chrome.md            # Chrome 验收规范
│
├── TranslatorApp/                # macOS App
│   ├── TranslatorApp.xcodeproj
│   ├── TranslatorApp/
│   │   ├── App/
│   │   ├── Core/
│   │   │   ├── Services/
│   │   │   │   ├── TranslationService.swift
│   │   │   │   ├── OCRService.swift
│   │   │   │   └── ScreenshotService.swift
│   │   │   └── Managers/
│   │   │       └── WordBookManager.swift
│   │   ├── Features/
│   │   │   ├── ScreenshotTranslate/
│   │   │   └── WordBook/
│   │   └── Models/
│   │       └── Word.swift
│   ├── NativeMessagingHost/      # Chrome 通信服务
│   │   ├── main.swift
│   │   ├── MessageHandler.swift
│   │   ├── HostTranslationService.swift
│   │   └── HostWordBookService.swift
│   └── TranslatorAppTests/
│
└── ChromeExtension/              # Chrome 扩展
    ├── manifest.json
    ├── src/
    │   ├── background.ts
    │   ├── content.ts
    │   ├── translator.ts
    │   ├── wordbook.ts
    │   ├── native-messenger.ts
    │   └── types.ts
    └── tests/
```

---

## 验收规范

- [通用原则](./validate.md)
- [macOS App](./validate-macos.md)
- [Chrome 扩展](./validate-chrome.md)
