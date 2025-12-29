import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createWordBookService, createWordEntry } from '../src/wordbook';
import type { NativeMessenger } from '../src/types';
import { ErrorCode } from '../src/errors';

describe('WordBookService', () => {
  let mockMessenger: NativeMessenger;

  beforeEach(() => {
    mockMessenger = {
      send: vi.fn(),
      isConnected: vi.fn().mockResolvedValue(true),
    };
  });

  describe('save', () => {
    it('should save word via native messenger', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({ success: true });

      const service = createWordBookService(mockMessenger);
      const word = createWordEntry('Hello', '你好', 'https://example.com');

      await service.save(word);

      expect(mockMessenger.send).toHaveBeenCalledWith({
        action: 'saveWord',
        payload: word,
      });
    });

    it('should throw SAVE_WORD_FAILED on save failure', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({
        success: false,
        error: 'Database error',
      });

      const service = createWordBookService(mockMessenger);
      const word = createWordEntry('Hello', '你好');

      await expect(service.save(word)).rejects.toMatchObject({
        code: ErrorCode.SAVE_WORD_FAILED,
        message: 'Database error',
      });
    });

    it('should throw SAVE_WORD_FAILED with default message when error is empty', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({
        success: false,
      });

      const service = createWordBookService(mockMessenger);
      const word = createWordEntry('Hello', '你好');

      await expect(service.save(word)).rejects.toMatchObject({
        code: ErrorCode.SAVE_WORD_FAILED,
        message: 'Failed to save word',
      });
    });

    it('should prevent duplicate saves in same session', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({ success: true });

      const service = createWordBookService(mockMessenger);
      const word = createWordEntry('Hello', '你好');

      await service.save(word);

      await expect(service.save(word)).rejects.toMatchObject({
        code: ErrorCode.WORD_ALREADY_EXISTS,
      });

      // Should only call messenger once
      expect(mockMessenger.send).toHaveBeenCalledTimes(1);
    });

    it('should treat case-insensitive as duplicate', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({ success: true });

      const service = createWordBookService(mockMessenger);

      await service.save(createWordEntry('Hello', '你好'));
      await expect(
        service.save(createWordEntry('HELLO', '你好'))
      ).rejects.toMatchObject({
        code: ErrorCode.WORD_ALREADY_EXISTS,
      });

      expect(mockMessenger.send).toHaveBeenCalledTimes(1);
    });

    it('should treat whitespace-trimmed as duplicate', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({ success: true });

      const service = createWordBookService(mockMessenger);

      await service.save(createWordEntry('Hello', '你好'));
      await expect(
        service.save(createWordEntry('  Hello  ', '你好'))
      ).rejects.toMatchObject({
        code: ErrorCode.WORD_ALREADY_EXISTS,
      });
    });

    it('should propagate messenger errors', async () => {
      const error = new Error('Network error');
      vi.mocked(mockMessenger.send).mockRejectedValue(error);

      const service = createWordBookService(mockMessenger);
      const word = createWordEntry('Hello', '你好');

      await expect(service.save(word)).rejects.toThrow('Network error');
    });

    it('should not add to local dedup on messenger failure', async () => {
      vi.mocked(mockMessenger.send).mockRejectedValue(new Error('Network error'));

      const service = createWordBookService(mockMessenger);
      const word = createWordEntry('Hello', '你好');

      await expect(service.save(word)).rejects.toThrow();

      // Word should not be marked as saved
      expect(await service.exists('Hello')).toBe(false);
    });
  });

  describe('exists', () => {
    it('should return false for new words', async () => {
      const service = createWordBookService(mockMessenger);
      expect(await service.exists('Hello')).toBe(false);
    });

    it('should return true for saved words', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({ success: true });

      const service = createWordBookService(mockMessenger);
      await service.save(createWordEntry('Hello', '你好'));

      expect(await service.exists('Hello')).toBe(true);
    });

    it('should be case insensitive', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({ success: true });

      const service = createWordBookService(mockMessenger);
      await service.save(createWordEntry('Hello', '你好'));

      expect(await service.exists('hello')).toBe(true);
      expect(await service.exists('HELLO')).toBe(true);
    });

    it('should trim whitespace', async () => {
      vi.mocked(mockMessenger.send).mockResolvedValue({ success: true });

      const service = createWordBookService(mockMessenger);
      await service.save(createWordEntry('Hello', '你好'));

      expect(await service.exists('  Hello  ')).toBe(true);
    });
  });
});

describe('createWordEntry', () => {
  it('should create valid word entry', () => {
    const word = createWordEntry('Hello', '你好', 'https://example.com');

    expect(word.text).toBe('Hello');
    expect(word.translation).toBe('你好');
    expect(word.source).toBe('webpage');
    expect(word.sourceURL).toBe('https://example.com');
    expect(word.tags).toEqual([]);
    expect(word.id).toBeDefined();
    expect(typeof word.id).toBe('string');
    expect(word.createdAt).toBeDefined();
    expect(typeof word.createdAt).toBe('number');
  });

  it('should trim text', () => {
    const word = createWordEntry('  Hello  ', '你好');
    expect(word.text).toBe('Hello');
  });

  it('should work without sourceURL', () => {
    const word = createWordEntry('Hello', '你好');

    expect(word.text).toBe('Hello');
    expect(word.translation).toBe('你好');
    expect(word.sourceURL).toBeUndefined();
  });

  it('should generate unique IDs', () => {
    const word1 = createWordEntry('Hello', '你好');
    const word2 = createWordEntry('World', '世界');

    expect(word1.id).not.toBe(word2.id);
  });
});
