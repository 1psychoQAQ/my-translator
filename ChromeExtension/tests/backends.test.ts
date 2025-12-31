import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { StoredWord, WordStorage } from '../src/backends/types';

// Mock chrome.storage.local
const mockStorage: Record<string, unknown> = {};

vi.stubGlobal('chrome', {
  storage: {
    local: {
      get: vi.fn((keys: string | string[]) => {
        const keyArray = Array.isArray(keys) ? keys : [keys];
        const result: Record<string, unknown> = {};
        for (const key of keyArray) {
          if (mockStorage[key] !== undefined) {
            result[key] = mockStorage[key];
          }
        }
        return Promise.resolve(result);
      }),
      set: vi.fn((items: Record<string, unknown>) => {
        Object.assign(mockStorage, items);
        return Promise.resolve();
      }),
      remove: vi.fn((keys: string | string[]) => {
        const keyArray = Array.isArray(keys) ? keys : [keys];
        for (const key of keyArray) {
          delete mockStorage[key];
        }
        return Promise.resolve();
      }),
      getBytesInUse: vi.fn(() => Promise.resolve(1024)),
    },
  },
  runtime: {
    sendNativeMessage: vi.fn(),
    lastError: null,
  },
});

// Import after mocking
import { createBrowserStorage } from '../src/backends/browser-storage';

describe('Browser Storage', () => {
  let storage: WordStorage;

  beforeEach(() => {
    // Clear mock storage
    Object.keys(mockStorage).forEach((key) => delete mockStorage[key]);
    storage = createBrowserStorage();
  });

  it('should save and retrieve a word', async () => {
    const word: StoredWord = {
      id: 'test-id-1',
      text: 'hello',
      translation: '你好',
      source: 'webpage',
      tags: [],
      createdAt: Date.now(),
    };

    await storage.save(word);
    const all = await storage.getAll();

    expect(all).toHaveLength(1);
    expect(all[0].text).toBe('hello');
    expect(all[0].translation).toBe('你好');
  });

  it('should check if word exists', async () => {
    const word: StoredWord = {
      id: 'test-id-2',
      text: 'World',
      translation: '世界',
      source: 'webpage',
      tags: [],
      createdAt: Date.now(),
    };

    expect(await storage.exists('world')).toBe(false);
    await storage.save(word);
    expect(await storage.exists('world')).toBe(true);
    expect(await storage.exists('World')).toBe(true); // Case insensitive
  });

  it('should prevent duplicate words', async () => {
    const word: StoredWord = {
      id: 'test-id-3',
      text: 'duplicate',
      translation: '重复',
      source: 'webpage',
      tags: [],
      createdAt: Date.now(),
    };

    await storage.save(word);

    const duplicate: StoredWord = {
      id: 'test-id-4',
      text: 'Duplicate', // Same word, different case
      translation: '重复2',
      source: 'webpage',
      tags: [],
      createdAt: Date.now(),
    };

    await expect(storage.save(duplicate)).rejects.toThrow('already exists');
  });

  it('should delete a word', async () => {
    const word: StoredWord = {
      id: 'test-id-5',
      text: 'deleteme',
      translation: '删除我',
      source: 'webpage',
      tags: [],
      createdAt: Date.now(),
    };

    await storage.save(word);
    expect(await storage.exists('deleteme')).toBe(true);

    await storage.delete('test-id-5');
    expect(await storage.exists('deleteme')).toBe(false);
  });

  it('should clear all words', async () => {
    const words: StoredWord[] = [
      {
        id: 'test-id-6',
        text: 'word1',
        translation: '词1',
        source: 'webpage',
        tags: [],
        createdAt: Date.now(),
      },
      {
        id: 'test-id-7',
        text: 'word2',
        translation: '词2',
        source: 'webpage',
        tags: [],
        createdAt: Date.now(),
      },
    ];

    for (const word of words) {
      await storage.save(word);
    }

    let all = await storage.getAll();
    expect(all).toHaveLength(2);

    await storage.clear();
    all = await storage.getAll();
    expect(all).toHaveLength(0);
  });

  it('should get storage info', async () => {
    const word: StoredWord = {
      id: 'test-id-8',
      text: 'info',
      translation: '信息',
      source: 'webpage',
      tags: [],
      createdAt: Date.now(),
    };

    await storage.save(word);
    const info = await storage.getInfo();

    expect(info.count).toBe(1);
    expect(info.sizeBytes).toBe(1024); // Mocked value
  });
});

describe('Backend Types', () => {
  it('should have correct StoredWord structure', () => {
    const word: StoredWord = {
      id: 'unique-id',
      text: 'test',
      translation: '测试',
      source: 'webpage',
      sourceURL: 'https://example.com',
      sentence: 'This is a test sentence.',
      tags: ['tag1', 'tag2'],
      createdAt: Date.now(),
    };

    expect(word.id).toBeDefined();
    expect(word.text).toBe('test');
    expect(word.source).toBe('webpage');
    expect(word.tags).toContain('tag1');
  });
});
