import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { createTranslationCache } from '../src/cache';

describe('TranslationCache', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('should store and retrieve translations', () => {
    const cache = createTranslationCache();

    cache.set('Hello', '你好');
    expect(cache.get('Hello')).toBe('你好');
  });

  it('should return null for missing keys', () => {
    const cache = createTranslationCache();
    expect(cache.get('Unknown')).toBeNull();
  });

  it('should be case insensitive', () => {
    const cache = createTranslationCache();

    cache.set('Hello', '你好');
    expect(cache.get('hello')).toBe('你好');
    expect(cache.get('HELLO')).toBe('你好');
  });

  it('should trim whitespace', () => {
    const cache = createTranslationCache();

    cache.set('  Hello  ', '你好');
    expect(cache.get('Hello')).toBe('你好');
    expect(cache.get('  Hello  ')).toBe('你好');
  });

  it('should expire entries after TTL', () => {
    const cache = createTranslationCache();

    cache.set('Hello', '你好');
    expect(cache.get('Hello')).toBe('你好');

    // Advance time by 25 hours (past 24-hour TTL)
    vi.advanceTimersByTime(25 * 60 * 60 * 1000);

    expect(cache.get('Hello')).toBeNull();
  });

  it('should not expire entries before TTL', () => {
    const cache = createTranslationCache();

    cache.set('Hello', '你好');

    // Advance time by 23 hours (before 24-hour TTL)
    vi.advanceTimersByTime(23 * 60 * 60 * 1000);

    expect(cache.get('Hello')).toBe('你好');
  });

  it('should clear all entries', () => {
    const cache = createTranslationCache();

    cache.set('Hello', '你好');
    cache.set('World', '世界');

    cache.clear();

    expect(cache.get('Hello')).toBeNull();
    expect(cache.get('World')).toBeNull();
  });

  it('should evict oldest entries when full', () => {
    const cache = createTranslationCache();

    // Fill cache with 500 entries (max size)
    for (let i = 0; i < 500; i++) {
      cache.set(`key${i}`, `value${i}`);
      vi.advanceTimersByTime(1); // Ensure different timestamps
    }

    // Add one more entry - should evict the oldest (key0)
    cache.set('newKey', 'newValue');

    // First entry should be evicted
    expect(cache.get('key0')).toBeNull();
    // Latest entries should still exist
    expect(cache.get('key499')).toBe('value499');
    expect(cache.get('newKey')).toBe('newValue');
  });

  it('should update existing entry timestamp on set', () => {
    const cache = createTranslationCache();

    cache.set('Hello', '你好');

    // Advance time by 20 hours
    vi.advanceTimersByTime(20 * 60 * 60 * 1000);

    // Update the entry
    cache.set('Hello', '您好');

    // Advance time by 10 more hours (total 30 hours from first set)
    vi.advanceTimersByTime(10 * 60 * 60 * 1000);

    // Entry should still be valid (only 10 hours since last set)
    expect(cache.get('Hello')).toBe('您好');
  });
});
