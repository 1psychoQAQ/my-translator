# Chrome 扩展验收规范

## 技术栈

| 组件 | 技术 |
|-----|------|
| 扩展规范 | Manifest V3 |
| 语言 | TypeScript（推荐）或 JavaScript |
| 构建 | Vite / Webpack（可选） |
| 测试 | Vitest / Jest |
| 通信 | Native Messaging API |

---

## 模块职责

| 模块 | 职责 | 文件 |
|-----|------|------|
| `content.ts` | 网页翻译注入 | content scripts |
| `content_video.ts` | 视频字幕拦截 | content scripts |
| `background.ts` | 后台服务 + Native Messaging | service worker |
| `translator.ts` | 翻译逻辑封装 | 共享模块 |
| `wordbook.ts` | 单词收藏逻辑 | 共享模块 |

---

## 依赖注入

Chrome 扩展使用**模块导出 + 参数传递**方式实现 DI：

### 接口定义

```typescript
// types.ts
export interface Translator {
  translate(text: string): Promise<string>;
}

export interface WordBookService {
  save(word: WordEntry): Promise<void>;
}

export interface NativeMessenger {
  send<T>(message: object): Promise<T>;
}

export interface WordEntry {
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

### 实现示例

```typescript
// translator.ts
import type { Translator, NativeMessenger } from './types';

export function createTranslator(messenger: NativeMessenger): Translator {
  return {
    async translate(text: string): Promise<string> {
      const response = await messenger.send<{ translation: string }>({
        action: 'translate',
        text,
      });
      return response.translation;
    },
  };
}

// native-messenger.ts
export function createNativeMessenger(hostName: string): NativeMessenger {
  return {
    send<T>(message: object): Promise<T> {
      return chrome.runtime.sendNativeMessage(hostName, message);
    },
  };
}
```

### 使用方式

```typescript
// background.ts
import { createNativeMessenger } from './native-messenger';
import { createTranslator } from './translator';

const messenger = createNativeMessenger('com.example.translator');
const translator = createTranslator(messenger);

// 测试时可注入 mock
// const mockMessenger = { send: async () => ({ translation: 'mock' }) };
// const translator = createTranslator(mockMessenger);
```

---

## 错误处理

### 错误类型

```typescript
// errors.ts
export class TranslatorError extends Error {
  constructor(
    public code: ErrorCode,
    message: string,
    public cause?: unknown
  ) {
    super(message);
    this.name = 'TranslatorError';
  }
}

export enum ErrorCode {
  NATIVE_MESSAGE_FAILED = 'NATIVE_MESSAGE_FAILED',
  TRANSLATION_FAILED = 'TRANSLATION_FAILED',
  SUBTITLE_NOT_FOUND = 'SUBTITLE_NOT_FOUND',
  SAVE_WORD_FAILED = 'SAVE_WORD_FAILED',
}

export function createError(code: ErrorCode, message: string, cause?: unknown) {
  return new TranslatorError(code, message, cause);
}
```

### 处理规范

```typescript
// ✅ 显式处理，向用户反馈
async function translateSelection(text: string): Promise<void> {
  try {
    const result = await translator.translate(text);
    showTranslationPopup(result);
  } catch (error) {
    if (error instanceof TranslatorError) {
      showErrorNotification(error.message);
    } else {
      showErrorNotification('翻译失败，请重试');
      console.error('Unexpected error:', error);
    }
  }
}

// ❌ 禁止静默失败
async function badTranslate(text: string): Promise<string> {
  try {
    return await translator.translate(text);
  } catch {
    return '';  // 错误被吞掉，用户不知道发生了什么
  }
}
```

### Promise 处理

```typescript
// ✅ async/await + try/catch
async function fetchSubtitles(): Promise<Subtitle[]> {
  try {
    const response = await fetch(subtitleUrl);
    if (!response.ok) {
      throw createError(ErrorCode.SUBTITLE_NOT_FOUND, '字幕加载失败');
    }
    return response.json();
  } catch (error) {
    throw createError(ErrorCode.SUBTITLE_NOT_FOUND, '无法获取字幕', error);
  }
}

// ✅ Promise.catch 也可以
chrome.runtime.sendNativeMessage(hostName, message)
  .then(handleResponse)
  .catch((error) => {
    showErrorNotification('与本地应用通信失败');
    console.error(error);
  });
```

---

## 测试规范

### 框架

- 推荐：Vitest（更快，ESM 原生支持）
- 备选：Jest

### Mock 示例

```typescript
// __tests__/translator.test.ts
import { describe, it, expect, vi } from 'vitest';
import { createTranslator } from '../translator';
import type { NativeMessenger } from '../types';

describe('Translator', () => {
  it('should translate text via native messenger', async () => {
    const mockMessenger: NativeMessenger = {
      send: vi.fn().mockResolvedValue({ translation: '你好' }),
    };

    const translator = createTranslator(mockMessenger);
    const result = await translator.translate('Hello');

    expect(result).toBe('你好');
    expect(mockMessenger.send).toHaveBeenCalledWith({
      action: 'translate',
      text: 'Hello',
    });
  });

  it('should throw on messenger error', async () => {
    const mockMessenger: NativeMessenger = {
      send: vi.fn().mockRejectedValue(new Error('Connection failed')),
    };

    const translator = createTranslator(mockMessenger);

    await expect(translator.translate('Hello')).rejects.toThrow();
  });
});
```

### Chrome API Mock

```typescript
// __tests__/setup.ts
import { vi } from 'vitest';

// Mock chrome API
global.chrome = {
  runtime: {
    sendNativeMessage: vi.fn(),
    onMessage: {
      addListener: vi.fn(),
    },
  },
  storage: {
    local: {
      get: vi.fn(),
      set: vi.fn(),
    },
  },
} as unknown as typeof chrome;
```

### 覆盖要求

| 模块 | 测试场景 | 覆盖率 |
|-----|---------|--------|
| `translator.ts` | 成功、失败、超时 | 100% |
| `wordbook.ts` | 保存、重复检测 | 100% |
| `content.ts` | DOM 操作、事件监听 | 关键路径 |
| `content_video.ts` | 字幕拦截逻辑 | 关键路径 |
| `background.ts` | 消息路由 | 关键路径 |

---

## 代码规范

### TypeScript 配置

```json
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  }
}
```

### 命名规范

```typescript
// ✅ 清晰
async function translateSelectedText(): Promise<void>
function createSubtitleObserver(): MutationObserver
const NATIVE_HOST_NAME = 'com.example.translator';

// ❌ 模糊
async function handle(): Promise<any>
function init(): void  // init 什么？
const name = 'xxx';
```

### Content Script 规范

```typescript
// ✅ 避免全局污染
(function() {
  // 所有代码在 IIFE 内
  const translator = createTranslator(messenger);
})();

// ✅ 使用 Shadow DOM 隔离样式
const shadow = element.attachShadow({ mode: 'closed' });
shadow.innerHTML = `<style>...</style><div>...</div>`;
```

### Manifest V3 规范

```json
{
  "manifest_version": 3,
  "permissions": ["nativeMessaging", "activeTab"],
  "host_permissions": ["<all_urls>"],
  "background": {
    "service_worker": "background.js",
    "type": "module"
  },
  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["content.js"]
    }
  ]
}
```

---

## 验收检查清单

### Phase 2: 沉浸式翻译 + 收藏

- [ ] Manifest V3 配置正确
- [ ] Content Script 能注入页面
- [ ] 段落翻译：原文下方显示译文
- [ ] 双语对照样式美观
- [ ] 双击单词触发翻译
- [ ] 双击单词可收藏到单词本
- [ ] Native Messaging 与 macOS 通信正常
- [ ] 翻译结果缓存（避免重复请求）
- [ ] 错误处理：翻译失败有 toast 提示
- [ ] 错误处理：通信失败有提示
- [ ] 单元测试：translator 模块 100% 覆盖
- [ ] 单元测试：wordbook 模块 100% 覆盖

### Phase 3: 视频字幕翻译

- [ ] YouTube 字幕拦截（TextTrack API）
- [ ] Bilibili 字幕拦截（DOM MutationObserver）
- [ ] 字幕发送到 macOS 翻译
- [ ] 翻译后字幕回显或发送到悬浮窗
- [ ] 字幕同步（时间轴对齐）
- [ ] 错误处理：无字幕有提示
- [ ] 错误处理：字幕格式不支持有提示

### 通用检查

- [ ] 无 console.log 遗留（生产环境）
- [ ] 无 any 类型（TypeScript）
- [ ] ESLint 检查通过
- [ ] 扩展加载无错误
- [ ] 扩展图标状态正确
