import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createTranslator } from '../src/translator';
import { createTranslationCache } from '../src/cache';
import type { NativeMessenger, TranslationCache } from '../src/types';
import { ErrorCode } from '../src/errors';

describe('Translator', () => {
  let mockMessenger: NativeMessenger;
  let cache: TranslationCache;

  beforeEach(() => {
    mockMessenger = {
      send: vi.fn(),
      isConnected: vi.fn().mockResolvedValue(true),
    };
    cache = createTranslationCache();
  });

  describe('translate', () => {
    it('should translate text via native messenger', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({
        success: true,
        translation: '你好',
      });

      const translator = createTranslator(mockMessenger, cache);
      const result = await translator.translate('Hello');

      expect(result).toBe('你好');
      expect(mockMessenger.send).toHaveBeenCalledWith({
        action: 'translate',
        payload: {
          text: 'Hello',
          targetLanguage: 'zh-Hans',
        },
      });
    });

    it('should return cached translation on second call', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({
        success: true,
        translation: '你好',
      });

      const translator = createTranslator(mockMessenger, cache);

      // First call - should hit messenger
      await translator.translate('Hello');
      expect(mockMessenger.send).toHaveBeenCalledTimes(1);

      // Second call - should use cache
      const result = await translator.translate('Hello');
      expect(result).toBe('你好');
      expect(mockMessenger.send).toHaveBeenCalledTimes(1);
    });

    it('should throw TRANSLATION_EMPTY on empty text', async () => {
      const translator = createTranslator(mockMessenger, cache);

      await expect(translator.translate('')).rejects.toMatchObject({
        code: ErrorCode.TRANSLATION_EMPTY,
      });

      expect(mockMessenger.send).not.toHaveBeenCalled();
    });

    it('should throw TRANSLATION_EMPTY on whitespace-only text', async () => {
      const translator = createTranslator(mockMessenger, cache);

      await expect(translator.translate('   ')).rejects.toMatchObject({
        code: ErrorCode.TRANSLATION_EMPTY,
      });

      expect(mockMessenger.send).not.toHaveBeenCalled();
    });

    it('should throw TRANSLATION_FAILED on failure response', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({
        success: false,
        error: 'Service unavailable',
      });

      const translator = createTranslator(mockMessenger, cache);

      await expect(translator.translate('Hello')).rejects.toMatchObject({
        code: ErrorCode.TRANSLATION_FAILED,
        message: 'Service unavailable',
      });
    });

    it('should throw TRANSLATION_FAILED with default message when error is empty', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({
        success: false,
      });

      const translator = createTranslator(mockMessenger, cache);

      await expect(translator.translate('Hello')).rejects.toMatchObject({
        code: ErrorCode.TRANSLATION_FAILED,
        message: 'Translation failed',
      });
    });

    it('should throw TRANSLATION_EMPTY on empty translation result', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({
        success: true,
        translation: '',
      });

      const translator = createTranslator(mockMessenger, cache);

      await expect(translator.translate('Hello')).rejects.toMatchObject({
        code: ErrorCode.TRANSLATION_EMPTY,
      });
    });

    it('should throw TRANSLATION_EMPTY on undefined translation result', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({
        success: true,
        translation: undefined,
      });

      const translator = createTranslator(mockMessenger, cache);

      await expect(translator.translate('Hello')).rejects.toMatchObject({
        code: ErrorCode.TRANSLATION_EMPTY,
      });
    });

    it('should use custom target language', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({
        success: true,
        translation: 'Bonjour',
      });

      const translator = createTranslator(mockMessenger, cache, {
        targetLanguage: 'fr',
      });

      await translator.translate('Hello');

      expect(mockMessenger.send).toHaveBeenCalledWith({
        action: 'translate',
        payload: {
          text: 'Hello',
          targetLanguage: 'fr',
        },
      });
    });

    it('should include source language when specified', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({
        success: true,
        translation: '你好',
      });

      const translator = createTranslator(mockMessenger, cache, {
        sourceLanguage: 'en',
        targetLanguage: 'zh-Hans',
      });

      await translator.translate('Hello');

      expect(mockMessenger.send).toHaveBeenCalledWith({
        action: 'translate',
        payload: {
          text: 'Hello',
          sourceLanguage: 'en',
          targetLanguage: 'zh-Hans',
        },
      });
    });

    it('should trim whitespace from text before translating', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({
        success: true,
        translation: '你好',
      });

      const translator = createTranslator(mockMessenger, cache);
      await translator.translate('  Hello  ');

      expect(mockMessenger.send).toHaveBeenCalledWith(
        expect.objectContaining({
          payload: expect.objectContaining({
            text: 'Hello',
          }),
        })
      );
    });

    it('should propagate messenger errors', async () => {
      const error = new Error('Network error');
      vi.mocked(mockMessenger.send).mockRejectedValue(error);

      const translator = createTranslator(mockMessenger, cache);

      await expect(translator.translate('Hello')).rejects.toThrow('Network error');
    });

    it('should cache translation with trimmed key', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({
        success: true,
        translation: '你好',
      });

      const translator = createTranslator(mockMessenger, cache);

      // Translate with whitespace
      await translator.translate('  Hello  ');

      // Should use cache for non-whitespace version
      const result = await translator.translate('Hello');
      expect(result).toBe('你好');
      expect(mockMessenger.send).toHaveBeenCalledTimes(1);
    });
  });
});
