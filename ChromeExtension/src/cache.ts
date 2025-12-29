import type { TranslationCache } from './types';

const CACHE_MAX_SIZE = 500;
const CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours

interface CacheEntry {
  translation: string;
  timestamp: number;
}

export function createTranslationCache(): TranslationCache {
  const cache = new Map<string, CacheEntry>();

  function normalizeKey(text: string): string {
    return text.trim().toLowerCase();
  }

  function isExpired(entry: CacheEntry): boolean {
    return Date.now() - entry.timestamp > CACHE_TTL;
  }

  function evictOldest(): void {
    if (cache.size < CACHE_MAX_SIZE) return;

    let oldestKey: string | null = null;
    let oldestTime = Infinity;

    for (const [key, entry] of cache.entries()) {
      if (entry.timestamp < oldestTime) {
        oldestTime = entry.timestamp;
        oldestKey = key;
      }
    }

    if (oldestKey) {
      cache.delete(oldestKey);
    }
  }

  return {
    get(text: string): string | null {
      const key = normalizeKey(text);
      const entry = cache.get(key);

      if (!entry) return null;

      if (isExpired(entry)) {
        cache.delete(key);
        return null;
      }

      return entry.translation;
    },

    set(text: string, translation: string): void {
      evictOldest();
      const key = normalizeKey(text);
      cache.set(key, {
        translation,
        timestamp: Date.now(),
      });
    },

    clear(): void {
      cache.clear();
    },
  };
}
