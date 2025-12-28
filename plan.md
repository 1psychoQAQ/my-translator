# 翻译工具开发计划

## 核心功能（来自 mind.md）

| # | 功能 | 平台 |
|---|------|-----|
| 1 | Chrome 沉浸式翻译 | Chrome 扩展 |
| 2 | Chrome 视频字幕翻译 | Chrome 扩展 |
| 3 | 单词本（手机电脑同步） | macOS + iOS/Android |
| 4 | 截图翻译 | macOS |

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
| Chrome 通信 | Native Messaging Host | ¥0 |

### Chrome 扩展

| 组件 | 技术 | 成本 |
|-----|------|-----|
| 扩展规范 | Manifest V3 | ¥0 |
| 语言 | TypeScript | ¥0 |
| 构建 | Vite（可选） | ¥0 |
| 测试 | Vitest | ¥0 |

### Flutter App

| 组件 | 技术 | 成本 |
|-----|------|-----|
| 框架 | Flutter | ¥0 |
| 状态管理 | Riverpod | ¥0 |
| 云同步 | Firebase Firestore | ¥0（免费额度） |

---

## 开发计划

### Phase 1: macOS 基础

**平台**: macOS

**目标**: 截图翻译 + 本地单词本

| 任务 | 模块 |
|-----|------|
| 创建 Xcode 项目 | - |
| 实现 `ScreenshotService` | 截图区域选择 |
| 实现 `OCRService` | Vision 文字识别 |
| 实现 `TranslationService` | Apple Translation |
| 实现截图翻译流程 | Cmd+Shift+T → OCR → 翻译 → 悬浮窗 |
| 实现 `WordBookManager` | SwiftData CRUD |
| 实现单词本 UI | 列表/搜索/删除 |

**验收**: [validate-macos.md - Phase 1](./validate-macos.md#phase-1-截图翻译--单词本)

---

### Phase 2: Chrome 扩展

**平台**: Chrome + macOS

**目标**: 沉浸式网页翻译 + 收藏单词

| 任务 | 模块 | 平台 |
|-----|------|-----|
| 创建扩展项目 | manifest.json | Chrome |
| 实现 Content Script | 网页段落翻译 | Chrome |
| 实现双语对照显示 | DOM 注入 | Chrome |
| 实现 Native Messaging Host | 消息收发 | macOS |
| 连通 Chrome ↔ macOS | 翻译请求/响应 | 两端 |
| 实现双击收藏 | 单词发送到 macOS | Chrome |
| 接收并保存单词 | WordBookManager | macOS |

**验收**:
- Chrome: [validate-chrome.md - Phase 2](./validate-chrome.md#phase-2-沉浸式翻译--收藏)
- macOS: [validate-macos.md - Phase 2](./validate-macos.md#phase-2-native-messaging)

---

### Phase 3: 视频字幕翻译

**平台**: Chrome + macOS

**目标**: YouTube/Bilibili 字幕翻译

| 任务 | 模块 | 平台 |
|-----|------|-----|
| YouTube 字幕拦截 | TextTrack API | Chrome |
| Bilibili 字幕拦截 | MutationObserver | Chrome |
| 字幕发送到 macOS | Native Messaging | Chrome |
| 翻译字幕 | TranslationService | macOS |
| 悬浮字幕窗口 | SwiftUI Window | macOS |
| 字幕同步显示 | 时间轴对齐 | macOS |

**验收**:
- Chrome: [validate-chrome.md - Phase 3](./validate-chrome.md#phase-3-视频字幕翻译)
- macOS: [validate-macos.md - Phase 3](./validate-macos.md#phase-3-视频字幕)

---

### Phase 4: 手机 App + 云同步

**平台**: macOS + Flutter (iOS/Android)

**目标**: 单词本跨设备同步

| 任务 | 模块 | 平台 |
|-----|------|-----|
| 创建 Flutter 项目 | - | Flutter |
| 集成 Firebase | Firestore 配置 | 两端 |
| 实现 `SyncService` | 上传/下载 | macOS |
| 实现 `SyncService` | 上传/下载 | Flutter |
| 实现离线队列 | 本地暂存 | 两端 |
| 实现冲突合并 | 时间戳策略 | 两端 |
| 单词本 UI | 列表/搜索/详情 | Flutter |
| 下拉刷新同步 | UI 交互 | Flutter |

**验收**:
- macOS: [validate-macos.md - Phase 4](./validate-macos.md#phase-4-同步)
- Flutter: [validate-flutter.md - Phase 4](./validate-flutter.md#phase-4-单词本--同步)

---

## 架构

```
┌─────────────────────────────────┐
│        Chrome 扩展               │
│   ① 沉浸式翻译                   │
│   ② 视频字幕拦截                 │
│   技术: TypeScript + Manifest V3 │
└─────────────┬───────────────────┘
              │ Native Messaging
┌─────────────▼───────────────────┐
│        macOS App                │
│   - 翻译引擎 (Translation)      │
│   - OCR (Vision)                │
│   ④ 截图翻译                     │
│   ③ 单词本 (SwiftData)          │
│   技术: SwiftUI + SwiftData      │
└─────────────┬───────────────────┘
              │ Firebase Firestore
┌─────────────▼───────────────────┐
│     Flutter App                 │
│   ③ 单词本（iOS + Android）      │
│   技术: Flutter + Riverpod      │
└─────────────────────────────────┘
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
    var source: String      // "webpage" | "video" | "screenshot"
    var sourceURL: String?
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
  source: 'webpage' | 'video' | 'screenshot';
  sourceURL?: string;
  tags: string[];
  createdAt: number;
  syncedAt?: number;
}
```

### Flutter (Dart)

```dart
@freezed
class Word with _$Word {
  const factory Word({
    required String id,
    required String text,
    required String translation,
    required String source,
    String? sourceURL,
    @Default([]) List<String> tags,
    required DateTime createdAt,
    DateTime? syncedAt,
  }) = _Word;

  factory Word.fromJson(Map<String, dynamic> json) => _$WordFromJson(json);
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
├── validate-flutter.md           # Flutter 验收规范
│
├── TranslatorApp/                # macOS App
│   ├── TranslatorApp.xcodeproj
│   ├── TranslatorApp/
│   │   ├── App/
│   │   │   └── TranslatorApp.swift
│   │   ├── Core/
│   │   │   ├── Services/
│   │   │   │   ├── TranslationService.swift
│   │   │   │   ├── OCRService.swift
│   │   │   │   ├── ScreenshotService.swift
│   │   │   │   └── SyncService.swift
│   │   │   ├── Managers/
│   │   │   │   └── WordBookManager.swift
│   │   │   └── NativeMessaging/
│   │   │       └── NativeMessagingHost.swift
│   │   ├── Features/
│   │   │   ├── ScreenshotTranslate/
│   │   │   ├── SubtitleWindow/
│   │   │   └── WordBook/
│   │   └── Models/
│   │       └── Word.swift
│   └── TranslatorAppTests/
│
├── ChromeExtension/              # Chrome 扩展
│   ├── manifest.json
│   ├── src/
│   │   ├── background.ts
│   │   ├── content.ts
│   │   ├── content_video.ts
│   │   ├── translator.ts
│   │   ├── wordbook.ts
│   │   └── types.ts
│   ├── tests/
│   └── vite.config.ts
│
└── translator_flutter/           # Flutter App
    ├── lib/
    │   ├── core/
    │   │   ├── errors.dart
    │   │   └── result.dart
    │   ├── models/
    │   │   └── word.dart
    │   ├── services/
    │   │   └── sync_service.dart
    │   ├── repositories/
    │   │   └── word_repository.dart
    │   ├── providers/
    │   │   └── providers.dart
    │   ├── screens/
    │   │   ├── word_book_screen.dart
    │   │   └── word_detail_screen.dart
    │   ├── widgets/
    │   │   ├── word_card.dart
    │   │   └── search_bar.dart
    │   └── main.dart
    └── test/
```

---

## 立即开始

1. ⬜ 创建 macOS Xcode 项目 (TranslatorApp)
2. ⬜ 实现 `ScreenshotService`
3. ⬜ 实现 `OCRService`
4. ⬜ 实现 `TranslationService`
5. ⬜ 实现截图翻译完整流程
6. ⬜ 实现 `WordBookManager`
7. ⬜ 实现单词本 UI

---

## 验收规范

- [通用原则](./validate.md)
- [macOS App](./validate-macos.md)
- [Chrome 扩展](./validate-chrome.md)
- [Flutter App](./validate-flutter.md)
