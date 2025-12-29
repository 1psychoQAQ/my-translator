import type { NativeMessenger, NativeMessage, PingResponse } from './types';
import { createError, ErrorCode } from './errors';

const NATIVE_HOST_NAME = 'com.liujiahao.translator';
const REQUEST_TIMEOUT = 30000; // 30 seconds

// Check if we're in a context where sendNativeMessage is available (background script)
function canUseNativeMessaging(): boolean {
  return typeof chrome !== 'undefined' &&
         typeof chrome.runtime !== 'undefined' &&
         typeof chrome.runtime.sendNativeMessage === 'function';
}

// Direct Native Messenger (for background script only)
export function createNativeMessenger(): NativeMessenger {
  return {
    send<T>(message: NativeMessage): Promise<T> {
      return new Promise((resolve, reject) => {
        const timeoutId = setTimeout(() => {
          reject(createError(ErrorCode.TIMEOUT, 'Native message timeout'));
        }, REQUEST_TIMEOUT);

        try {
          chrome.runtime.sendNativeMessage(
            NATIVE_HOST_NAME,
            message,
            (response: T | undefined) => {
              clearTimeout(timeoutId);

              if (chrome.runtime.lastError) {
                const errorMessage = chrome.runtime.lastError.message || '';
                if (errorMessage.includes('not found')) {
                  reject(
                    createError(ErrorCode.NATIVE_HOST_NOT_FOUND, errorMessage)
                  );
                } else {
                  reject(
                    createError(ErrorCode.NATIVE_MESSAGE_FAILED, errorMessage)
                  );
                }
                return;
              }

              if (!response) {
                reject(
                  createError(
                    ErrorCode.INVALID_RESPONSE,
                    'Empty response from native host'
                  )
                );
                return;
              }

              resolve(response);
            }
          );
        } catch (error) {
          clearTimeout(timeoutId);
          reject(
            createError(
              ErrorCode.NATIVE_MESSAGE_FAILED,
              'Failed to send native message',
              error
            )
          );
        }
      });
    },

    async isConnected(): Promise<boolean> {
      try {
        const response = await this.send<PingResponse>({
          action: 'ping',
          payload: {},
        });
        return response.success === true;
      } catch {
        return false;
      }
    },
  };
}

// Proxy Messenger for content scripts - sends messages to background script
export function createProxyMessenger(): NativeMessenger {
  return {
    send<T>(message: NativeMessage): Promise<T> {
      return new Promise((resolve, reject) => {
        const timeoutId = setTimeout(() => {
          reject(createError(ErrorCode.TIMEOUT, 'Message timeout'));
        }, REQUEST_TIMEOUT);

        chrome.runtime.sendMessage(
          { type: 'NATIVE_MESSAGE', payload: message },
          (response: { success: boolean; data?: T; error?: string }) => {
            clearTimeout(timeoutId);

            if (chrome.runtime.lastError) {
              reject(
                createError(
                  ErrorCode.NATIVE_MESSAGE_FAILED,
                  chrome.runtime.lastError.message || 'Failed to send message'
                )
              );
              return;
            }

            if (!response) {
              reject(
                createError(ErrorCode.INVALID_RESPONSE, 'Empty response')
              );
              return;
            }

            if (!response.success) {
              reject(
                createError(
                  ErrorCode.NATIVE_MESSAGE_FAILED,
                  response.error || 'Request failed'
                )
              );
              return;
            }

            resolve(response.data as T);
          }
        );
      });
    },

    async isConnected(): Promise<boolean> {
      try {
        const response = await this.send<PingResponse>({
          action: 'ping',
          payload: {},
        });
        return response.success === true;
      } catch {
        return false;
      }
    },
  };
}

// Mock messenger for development/testing when native host is unavailable
export function createMockMessenger(): NativeMessenger {
  const mockTranslations: Record<string, string> = {
    Hello: '你好',
    World: '世界',
    'Hello, World!': '你好，世界！',
    'Good morning': '早上好',
    'Thank you': '谢谢',
  };

  return {
    async send<T>(message: NativeMessage): Promise<T> {
      // Simulate network delay
      await new Promise((r) => setTimeout(r, 100));

      if (message.action === 'translate') {
        const payload = message.payload as { text: string };
        const translation =
          mockTranslations[payload.text] || `[翻译] ${payload.text}`;
        return {
          success: true,
          translation,
        } as T;
      }

      if (message.action === 'saveWord') {
        return { success: true } as T;
      }

      if (message.action === 'ping') {
        return { success: true, version: '1.0.0-mock' } as T;
      }

      return { success: false, error: 'Unknown action' } as T;
    },

    async isConnected(): Promise<boolean> {
      return true;
    },
  };
}

// Auto-detect and create appropriate messenger
export async function createMessengerWithFallback(): Promise<NativeMessenger> {
  // Content scripts must use proxy messenger (sendNativeMessage not available)
  // Background script can use direct native messenger
  const messenger = canUseNativeMessaging()
    ? createNativeMessenger()
    : createProxyMessenger();

  try {
    const connected = await messenger.isConnected();
    if (connected) {
      return messenger;
    }
  } catch {
    // Fall through to mock
  }

  return createMockMessenger();
}
