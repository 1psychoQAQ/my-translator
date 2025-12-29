import { vi } from 'vitest';
import type { Mock } from 'vitest';

type SendNativeMessageCallback = (response: unknown) => void;
type SendNativeMessageFn = (host: string, message: unknown, callback: SendNativeMessageCallback) => void;

interface MockChromeRuntime {
  sendNativeMessage: Mock<SendNativeMessageFn>;
  sendMessage: Mock;
  onMessage: {
    addListener: Mock;
    removeListener: Mock;
  };
  lastError: { message?: string } | null;
}

interface MockChrome {
  runtime: MockChromeRuntime;
  storage: {
    local: {
      get: Mock;
      set: Mock;
    };
  };
}

// Mock Chrome APIs
const mockChrome: MockChrome = {
  runtime: {
    sendNativeMessage: vi.fn(),
    sendMessage: vi.fn(),
    onMessage: {
      addListener: vi.fn(),
      removeListener: vi.fn(),
    },
    lastError: null,
  },
  storage: {
    local: {
      get: vi.fn(),
      set: vi.fn(),
    },
  },
};

// @ts-expect-error - Mocking global chrome
globalThis.chrome = mockChrome;

// Reset mocks before each test
beforeEach(() => {
  vi.clearAllMocks();
  mockChrome.runtime.lastError = null;
});

export { mockChrome };
