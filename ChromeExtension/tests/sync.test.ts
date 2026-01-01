import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { StoredWord } from '../src/backends/types';
import type { SyncData } from '../src/sync/types';
import {
  exportToJson,
  parseImportData,
  generateExportFilename,
} from '../src/sync/export-import';
import { createSyncData, generateDeviceId, SYNC_DATA_VERSION } from '../src/sync/types';

// Mock localStorage
const mockLocalStorage: Record<string, string> = {};

vi.stubGlobal('localStorage', {
  getItem: vi.fn((key: string) => mockLocalStorage[key] || null),
  setItem: vi.fn((key: string, value: string) => {
    mockLocalStorage[key] = value;
  }),
  removeItem: vi.fn((key: string) => {
    delete mockLocalStorage[key];
  }),
});

describe('Export/Import', () => {
  const sampleWords: StoredWord[] = [
    {
      id: 'word-1',
      text: 'hello',
      translation: '你好',
      source: 'webpage',
      sourceURL: 'https://example.com',
      sentence: 'Hello, world!',
      tags: ['greeting'],
      createdAt: 1700000000000,
    },
    {
      id: 'word-2',
      text: 'world',
      translation: '世界',
      source: 'webpage',
      tags: [],
      createdAt: 1700000001000,
    },
  ];

  beforeEach(() => {
    Object.keys(mockLocalStorage).forEach((key) => delete mockLocalStorage[key]);
  });

  describe('exportToJson', () => {
    it('should export with metadata by default', () => {
      const json = exportToJson(sampleWords);
      const parsed = JSON.parse(json) as SyncData;

      expect(parsed.version).toBe(SYNC_DATA_VERSION);
      expect(parsed.metadata.wordCount).toBe(2);
      expect(parsed.words).toHaveLength(2);
    });

    it('should export without metadata when specified', () => {
      const json = exportToJson(sampleWords, { includeMetadata: false });
      const parsed = JSON.parse(json) as StoredWord[];

      expect(Array.isArray(parsed)).toBe(true);
      expect(parsed).toHaveLength(2);
    });

    it('should filter by date range', () => {
      const json = exportToJson(sampleWords, {
        dateRange: { from: 1700000000500 },
      });
      const parsed = JSON.parse(json) as SyncData;

      expect(parsed.words).toHaveLength(1);
      expect(parsed.words[0].text).toBe('world');
    });

    it('should filter by tags', () => {
      const json = exportToJson(sampleWords, {
        tags: ['greeting'],
      });
      const parsed = JSON.parse(json) as SyncData;

      expect(parsed.words).toHaveLength(1);
      expect(parsed.words[0].text).toBe('hello');
    });
  });

  describe('parseImportData', () => {
    it('should parse SyncData format', () => {
      const syncData = createSyncData(sampleWords, 'test-device');
      const json = JSON.stringify(syncData);

      const parsed = parseImportData(json);

      expect(parsed).toHaveLength(2);
      expect(parsed[0].text).toBe('hello');
    });

    it('should parse direct array format', () => {
      const json = JSON.stringify(sampleWords);

      const parsed = parseImportData(json);

      expect(parsed).toHaveLength(2);
    });

    it('should validate required fields', () => {
      const invalidData = [
        { translation: '测试' }, // missing text
        { text: 'test' }, // missing translation
      ];
      const json = JSON.stringify(invalidData);

      expect(() => parseImportData(json)).toThrow('All entries invalid');
    });

    it('should add defaults for optional fields', () => {
      const minimalData = [
        { text: 'test', translation: '测试' },
      ];
      const json = JSON.stringify(minimalData);

      const parsed = parseImportData(json);

      expect(parsed[0].id).toBeDefined();
      expect(parsed[0].source).toBe('webpage');
      expect(parsed[0].tags).toEqual([]);
      expect(parsed[0].createdAt).toBeGreaterThan(0);
    });
  });

  describe('generateExportFilename', () => {
    it('should generate filename with timestamp', () => {
      const filename = generateExportFilename();

      expect(filename).toMatch(/^translator-wordbook-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.json$/);
    });
  });
});

describe('Sync Types', () => {
  beforeEach(() => {
    Object.keys(mockLocalStorage).forEach((key) => delete mockLocalStorage[key]);
  });

  describe('createSyncData', () => {
    it('should create valid SyncData', () => {
      const words: StoredWord[] = [
        {
          id: 'test-id',
          text: 'test',
          translation: '测试',
          source: 'webpage',
          tags: [],
          createdAt: Date.now(),
        },
      ];

      const syncData = createSyncData(words, 'device-123');

      expect(syncData.version).toBe(SYNC_DATA_VERSION);
      expect(syncData.metadata.deviceId).toBe('device-123');
      expect(syncData.metadata.wordCount).toBe(1);
      expect(syncData.words).toEqual(words);
    });
  });

  describe('generateDeviceId', () => {
    it('should generate and persist device ID', () => {
      const id1 = generateDeviceId();
      const id2 = generateDeviceId();

      expect(id1).toBe(id2); // Should return same ID
      expect(id1).toMatch(/^device_\d+_[a-z0-9]+$/);
    });
  });
});
