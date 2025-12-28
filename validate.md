# 验收规范（通用原则）

本文档定义跨平台通用的工程原则。各平台具体规范见：

- [macOS App 验收规范](./validate-macos.md)
- [Chrome 扩展验收规范](./validate-chrome.md)
- [Flutter App 验收规范](./validate-flutter.md)

---

## 工程原则

| 原则 | 要求 | 适用平台 |
|-----|------|---------|
| 可测试性 | 核心模块必须有单元测试 | 全部 |
| 单一职责 | 模块职责单一，边界清晰 | 全部 |
| 显式错误 | 所有错误必须显式处理，禁止静默失败 | 全部 |
| 最小依赖 | 优先系统/官方框架，不引入非必要第三方库 | 全部 |
| 依赖注入 | 核心服务通过 DI 注入，便于测试和替换 | 全部 |

---

## 单一职责

每个模块只做一件事：

| 职责类型 | 正确 | 错误 |
|---------|------|------|
| 翻译 | `translate(text) → translation` | `screenshotAndTranslate()` |
| OCR | `extractText(image) → text` | `ocrAndSave()` |
| 存储 | `save(word)` / `fetch()` | `translateAndSave()` |
| 同步 | `upload()` / `download()` | `syncAndNotify()` |

**原则**：一个函数/类只做一件事，组合在上层完成。

---

## 依赖注入

### 为什么需要 DI？

1. **可测试**：注入 Mock 进行单元测试
2. **可替换**：切换实现不改调用方
3. **解耦**：模块间通过接口通信

### 各平台 DI 方式

| 平台 | DI 方式 | 示例 |
|-----|---------|------|
| macOS (Swift) | 协议 + 构造器注入 | `init(service: ServiceProtocol)` |
| Chrome (TS) | 接口 + 工厂函数 | `createTranslator(messenger)` |
| Flutter (Dart) | Riverpod Provider | `ref.watch(serviceProvider)` |

### 哪些需要 DI？

| 类型 | 需要 DI | 原因 |
|-----|--------|------|
| 核心服务（翻译/OCR/同步） | ✅ | 需测试，可能换实现 |
| 数据仓库 | ✅ | 需 Mock 数据源 |
| 系统 API 封装 | ❌ | 简单封装，固定实现 |
| UI 组件 | ❌ | 通过状态驱动 |
| 数据模型 | ❌ | 纯数据结构 |

---

## 错误处理

### 原则

- ✅ 所有错误必须显式抛出/返回
- ✅ 上层统一捕获和处理
- ✅ 用户可见的错误必须有友好提示
- ❌ 禁止静默忽略错误
- ❌ 禁止空 catch / 空 catchError

### 各平台错误处理

| 平台 | 推荐方式 |
|-----|---------|
| macOS (Swift) | `throws` + `do-catch` + 自定义 `Error` enum |
| Chrome (TS) | `Promise` + `try-catch` + 自定义 `Error` class |
| Flutter (Dart) | `Result<T>` sealed class 或 `try-catch` |

### 用户提示

| 错误类型 | 提示方式 |
|---------|---------|
| 网络错误 | Toast/SnackBar: "网络连接失败，请检查网络" |
| 翻译失败 | Alert/Dialog: "翻译服务暂时不可用" |
| 权限拒绝 | 引导页: "请在系统设置中授权..." |
| 数据冲突 | 静默处理，以时间戳为准 |

---

## 测试策略

### 测试金字塔

```
        ┌─────────┐
        │  E2E    │  ← 少量，验证完整流程
        ├─────────┤
        │ 集成    │  ← 中等，验证模块协作
        ├─────────┤
        │ 单元    │  ← 大量，验证单一功能
        └─────────┘
```

### 各平台测试框架

| 平台 | 单元测试 | 集成测试 | E2E |
|-----|---------|---------|-----|
| macOS | XCTest | XCTest | XCUITest |
| Chrome | Vitest/Jest | Vitest/Jest | Puppeteer（可选） |
| Flutter | flutter_test | flutter_test | integration_test |

### 覆盖率要求

| 模块类型 | 覆盖率要求 |
|---------|-----------|
| 核心服务 | 100% |
| 数据仓库 | 100% |
| 状态管理 | 100% |
| UI 组件 | 关键路径 |
| 系统封装 | 可选 |

---

## 依赖清单

### 允许的依赖

| 平台 | 允许 |
|-----|------|
| macOS | SwiftUI, SwiftData, Vision, Translation, ScreenCaptureKit, Firebase SDK |
| Chrome | Manifest V3 原生 API, TypeScript |
| Flutter | flutter, riverpod, firebase_core, cloud_firestore, freezed |

### 禁止引入

- ❌ 不必要的 UI 库（系统组件足够）
- ❌ 不必要的网络库（系统 API 足够）
- ❌ 不必要的工具库（几行代码能解决的）
- ❌ 过度封装的状态管理库

---

## 代码规范

### 命名

| 类型 | 规范 | 示例 |
|-----|------|------|
| 函数 | 动词开头，描述行为 | `translateText()`, `saveWord()` |
| 变量 | 名词，描述内容 | `translatedText`, `wordList` |
| 布尔值 | is/has/should 前缀 | `isLoading`, `hasError` |
| 常量 | 大写下划线（JS/Dart）或驼峰（Swift） | `API_TIMEOUT`, `apiTimeout` |

### 函数设计

- 单一职责：一个函数只做一件事
- 参数不超过 3 个，多了用对象/结构体
- 返回类型明确，避免 any/dynamic
- 副作用明确标注（async, throws 等）

---

## 验收总检查清单

### Phase 1: macOS 基础

详见 [validate-macos.md](./validate-macos.md#phase-1-截图翻译--单词本)

### Phase 2: Chrome 扩展

详见 [validate-chrome.md](./validate-chrome.md#phase-2-沉浸式翻译--收藏)

### Phase 3: 视频字幕

- macOS 部分：[validate-macos.md](./validate-macos.md#phase-3-视频字幕)
- Chrome 部分：[validate-chrome.md](./validate-chrome.md#phase-3-视频字幕翻译)

### Phase 4: 手机 App + 同步

- macOS 同步：[validate-macos.md](./validate-macos.md#phase-4-同步)
- Flutter App：[validate-flutter.md](./validate-flutter.md#phase-4-单词本--同步)
