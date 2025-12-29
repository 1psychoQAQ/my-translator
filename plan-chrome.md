# Chrome Extension (Phase 2) Implementation Plan

## Overview

从头创建Chrome扩展，实现沉浸式网页翻译功能，通过Native Messaging与macOS App通信。

**当前状态**: ✅ Phase 2 基础功能已完成
- ChromeExtension 目录已创建，核心功能已实现
- macOS 端 Native Messaging Host 已实现并集成
- 双击单词翻译 ✅
- 单词收藏到 macOS 单词本 ✅
- 全页翻译 ✅
- 恢复原文 ✅

## Architecture

```
Chrome Extension (content.ts)
       ↓ chrome.runtime.sendMessage
Background Service Worker (background.ts)
       ↓ NATIVE_MESSAGE proxy
       ↓ chrome.runtime.sendNativeMessage
macOS App (NativeMessagingHost) ← ✅ 已实现
       ↓
TranslationService / WordBookManager ← ✅ 已集成
       ↓
SwiftData (~/Library/Application Support/com.translator.app/default.store)
```

### 关键实现细节

1. **Content Script 不能直接调用 `sendNativeMessage`**，必须通过 Background Script 代理
2. **SwiftData 路径必须统一**：NativeMessagingHost 和 TranslatorApp 使用相同的 `com.translator.app` 路径
3. **Model 类名必须一致**：两边都使用 `Word` 类（不是 `HostWord`）

## Directory Structure

```
ChromeExtension/
├── manifest.json           # Manifest V3
├── package.json
├── tsconfig.json
├── vite.config.ts
├── vitest.config.ts
├── src/
│   ├── types.ts            # 接口定义
│   ├── errors.ts           # 错误类型
│   ├── cache.ts            # 翻译缓存
│   ├── native-messenger.ts # Native Messaging封装
│   ├── translator.ts       # 翻译模块
│   ├── wordbook.ts         # 单词收藏模块
│   ├── toast.ts            # Toast通知UI
│   ├── content.ts          # Content Script
│   └── background.ts       # Service Worker
├── tests/
│   ├── setup.ts
│   ├── translator.test.ts  # 100%覆盖
│   ├── wordbook.test.ts    # 100%覆盖
│   └── cache.test.ts
└── dist/
```

## Implementation Steps

### Step 1: Project Setup
**Files to create:**
- `ChromeExtension/package.json`
- `ChromeExtension/tsconfig.json`
- `ChromeExtension/vite.config.ts`
- `ChromeExtension/vitest.config.ts`
- `ChromeExtension/manifest.json`

**Dependencies:**
- typescript, vite, vitest
- @types/chrome
- @vitest/coverage-v8
- eslint + typescript-eslint

### Step 2: Core Types & Errors
**Files to create:**
- `src/types.ts` - WordEntry, Translator, NativeMessenger等接口
- `src/errors.ts` - TranslatorError类, ErrorCode枚举

### Step 3: Translation Cache
**Files to create:**
- `src/cache.ts` - 翻译结果缓存（LRU, 24h TTL）
- `tests/cache.test.ts`

### Step 4: Native Messenger
**Files to create:**
- `src/native-messenger.ts`
  - `createNativeMessenger()` - 真实Native Messaging
  - `createMockMessenger()` - 开发用Mock
- `tests/native-messenger.test.ts`

### Step 5: Translator Module
**Files to create:**
- `src/translator.ts` - createTranslator(messenger, cache)
- `tests/translator.test.ts` - **100%覆盖率**

测试场景：成功翻译、缓存命中、空文本、翻译失败、空结果

### Step 6: WordBook Module
**Files to create:**
- `src/wordbook.ts` - createWordBookService(messenger)
- `tests/wordbook.test.ts` - **100%覆盖率**

测试场景：保存成功、保存失败、重复检测

### Step 7: Toast Notifications
**Files to create:**
- `src/toast.ts` - Shadow DOM隔离的通知UI

### Step 8: Content Script
**Files to create:**
- `src/content.ts`

功能实现：
1. 双语对照注入（Shadow DOM隔离样式）
2. 双击单词翻译
3. 单词弹窗（翻译+收藏按钮）
4. 段落翻译检测

### Step 9: Background Service Worker
**Files to create:**
- `src/background.ts`

功能：消息路由、Native Messaging通信

### Step 10: Extension Assets
**Files to create:**
- `icons/icon16.png`, `icon32.png`, `icon48.png`, `icon128.png`

## Key Design Decisions

### 依赖注入
```typescript
// 工厂函数 + 接口参数
const messenger = createNativeMessenger();
const cache = createTranslationCache();
const translator = createTranslator(messenger, cache);
```

### 错误处理
```typescript
// 显式错误，用户可见反馈
try {
  await translator.translate(text);
} catch (error) {
  if (error instanceof TranslatorError) {
    toast.error(getUserMessage(error.code));
  }
}
```

### DOM隔离
```typescript
// Shadow DOM防止样式冲突
const shadow = element.attachShadow({ mode: 'closed' });
```

### Native Messaging协议
```json
// Request
{ "action": "translate", "payload": { "text": "Hello", "targetLanguage": "zh-Hans" } }
// Response
{ "success": true, "translation": "你好" }
```

## Acceptance Criteria (from validate-chrome.md)

- [x] Manifest V3配置正确
- [x] Content Script能注入页面
- [x] 段落翻译：原文下方显示译文
- [x] 双语对照样式美观（Shadow DOM隔离，自适应背景色）
- [x] 双击单词触发翻译
- [x] 双击单词可收藏到单词本
- [x] Native Messaging与macOS通信正常
- [x] 翻译结果缓存（LRU, 24h TTL）
- [x] 错误处理：翻译失败有toast提示
- [x] 单元测试：translator模块100%覆盖
- [x] 单元测试：wordbook模块100%覆盖
- [x] 恢复原文功能（右键菜单）
- [ ] 无console.log遗留（开发阶段保留）
- [ ] 无any类型
- [ ] ESLint检查通过

## Development Strategy

~~由于macOS Native Messaging Host未实现，采用Mock优先策略：~~ ✅ 已完成

1. ~~使用`createMockMessenger()`开发和测试Chrome扩展~~ ✅
2. ~~完成Chrome扩展后，再实现macOS端`NativeMessagingHost.swift`~~ ✅
3. ~~最后进行端到端集成测试~~ ✅

**当前状态**: Native Messaging 已完全集成，Chrome 扩展可通过 `createMessengerWithFallback()` 自动检测并使用真实的 Native Messaging Host。

## Commands

```bash
cd ChromeExtension
npm install           # 安装依赖
npm run dev           # 开发模式（watch）
npm run build         # 构建
npm run test          # 运行测试
npm run test:coverage # 覆盖率报告
npm run lint          # ESLint检查
```
