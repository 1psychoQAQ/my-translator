import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mockChrome } from './setup';
import { createNativeMessenger, createMockMessenger } from '../src/native-messenger';
import { ErrorCode } from '../src/errors';

type MockCallback = (response: unknown) => void;

describe('NativeMessenger', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockChrome.runtime.lastError = null;
  });

  describe('createNativeMessenger', () => {
    it('should send message and receive response', async () => {
      const expectedResponse = { success: true, translation: '你好' };
      mockChrome.runtime.sendNativeMessage.mockImplementation(
        (_host: string, _message: unknown, callback: MockCallback) => {
          callback(expectedResponse);
        }
      );

      const messenger = createNativeMessenger();
      const response = await messenger.send({
        action: 'translate',
        payload: { text: 'Hello' },
      });

      expect(response).toEqual(expectedResponse);
      expect(mockChrome.runtime.sendNativeMessage).toHaveBeenCalledWith(
        'com.translator.app',
        { action: 'translate', payload: { text: 'Hello' } },
        expect.any(Function)
      );
    });

    it('should throw NATIVE_HOST_NOT_FOUND on host not found error', async () => {
      mockChrome.runtime.sendNativeMessage.mockImplementation(
        (_host: string, _message: unknown, callback: MockCallback) => {
          mockChrome.runtime.lastError = { message: 'Native host not found' };
          callback(undefined);
        }
      );

      const messenger = createNativeMessenger();

      await expect(
        messenger.send({ action: 'ping', payload: {} })
      ).rejects.toMatchObject({
        code: ErrorCode.NATIVE_HOST_NOT_FOUND,
      });
    });

    it('should throw NATIVE_MESSAGE_FAILED on other errors', async () => {
      mockChrome.runtime.sendNativeMessage.mockImplementation(
        (_host: string, _message: unknown, callback: MockCallback) => {
          mockChrome.runtime.lastError = { message: 'Connection failed' };
          callback(undefined);
        }
      );

      const messenger = createNativeMessenger();

      await expect(
        messenger.send({ action: 'ping', payload: {} })
      ).rejects.toMatchObject({
        code: ErrorCode.NATIVE_MESSAGE_FAILED,
      });
    });

    it('should throw INVALID_RESPONSE on empty response', async () => {
      mockChrome.runtime.sendNativeMessage.mockImplementation(
        (_host: string, _message: unknown, callback: MockCallback) => {
          callback(undefined);
        }
      );

      const messenger = createNativeMessenger();

      await expect(
        messenger.send({ action: 'ping', payload: {} })
      ).rejects.toMatchObject({
        code: ErrorCode.INVALID_RESPONSE,
      });
    });

    it('should timeout after 30 seconds', async () => {
      vi.useFakeTimers();

      mockChrome.runtime.sendNativeMessage.mockImplementation(() => {
        // Never call callback - simulate timeout
      });

      const messenger = createNativeMessenger();
      const promise = messenger.send({ action: 'ping', payload: {} });

      vi.advanceTimersByTime(30000);

      await expect(promise).rejects.toMatchObject({
        code: ErrorCode.TIMEOUT,
      });

      vi.useRealTimers();
    });

    describe('isConnected', () => {
      it('should return true when ping succeeds', async () => {
        mockChrome.runtime.sendNativeMessage.mockImplementation(
          (_host: string, _message: unknown, callback: MockCallback) => {
            callback({ success: true });
          }
        );

        const messenger = createNativeMessenger();
        const connected = await messenger.isConnected();

        expect(connected).toBe(true);
      });

      it('should return false when ping fails', async () => {
        mockChrome.runtime.sendNativeMessage.mockImplementation(
          (_host: string, _message: unknown, callback: MockCallback) => {
            mockChrome.runtime.lastError = { message: 'Connection failed' };
            callback(undefined);
          }
        );

        const messenger = createNativeMessenger();
        const connected = await messenger.isConnected();

        expect(connected).toBe(false);
      });

      it('should return false when response.success is false', async () => {
        mockChrome.runtime.sendNativeMessage.mockImplementation(
          (_host: string, _message: unknown, callback: MockCallback) => {
            callback({ success: false });
          }
        );

        const messenger = createNativeMessenger();
        const connected = await messenger.isConnected();

        expect(connected).toBe(false);
      });
    });
  });

  describe('createMockMessenger', () => {
    it('should translate known text', async () => {
      const messenger = createMockMessenger();
      const response = await messenger.send<{ success: boolean; translation: string }>({
        action: 'translate',
        payload: { text: 'Hello' },
      });

      expect(response.success).toBe(true);
      expect(response.translation).toBe('你好');
    });

    it('should return placeholder for unknown text', async () => {
      const messenger = createMockMessenger();
      const response = await messenger.send<{ success: boolean; translation: string }>({
        action: 'translate',
        payload: { text: 'Unknown text' },
      });

      expect(response.success).toBe(true);
      expect(response.translation).toBe('[翻译] Unknown text');
    });

    it('should handle saveWord action', async () => {
      const messenger = createMockMessenger();
      const response = await messenger.send<{ success: boolean }>({
        action: 'saveWord',
        payload: { text: 'Hello', translation: '你好' },
      });

      expect(response.success).toBe(true);
    });

    it('should handle ping action', async () => {
      const messenger = createMockMessenger();
      const response = await messenger.send<{ success: boolean; version: string }>({
        action: 'ping',
        payload: {},
      });

      expect(response.success).toBe(true);
      expect(response.version).toBe('1.0.0-mock');
    });

    it('should always be connected', async () => {
      const messenger = createMockMessenger();
      const connected = await messenger.isConnected();

      expect(connected).toBe(true);
    });
  });
});
