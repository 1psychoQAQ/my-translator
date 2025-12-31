/**
 * Browser Storage - Uses chrome.storage.local
 * Cross-platform word storage without native dependencies
 */

import type { WordStorage, StoredWord } from './types';

const STORAGE_KEY = 'translator_wordbook';
const INDEX_KEY = 'translator_wordbook_index';

interface WordIndex {
  // Map of lowercase text -> word id for quick lookup
  textToId: Record<string, string>;
}

export function createBrowserStorage(): WordStorage {
  async function getWords(): Promise<StoredWord[]> {
    const result = await chrome.storage.local.get(STORAGE_KEY);
    return (result[STORAGE_KEY] as StoredWord[] | undefined) || [];
  }

  async function setWords(words: StoredWord[]): Promise<void> {
    await chrome.storage.local.set({ [STORAGE_KEY]: words });
  }

  async function getIndex(): Promise<WordIndex> {
    const result = await chrome.storage.local.get(INDEX_KEY);
    return (result[INDEX_KEY] as WordIndex | undefined) || { textToId: {} };
  }

  async function setIndex(index: WordIndex): Promise<void> {
    await chrome.storage.local.set({ [INDEX_KEY]: index });
  }

  return {
    async save(word: StoredWord): Promise<void> {
      const words = await getWords();
      const index = await getIndex();

      // Check for duplicates
      const normalizedText = word.text.toLowerCase();
      if (index.textToId[normalizedText]) {
        throw new Error(`Word "${word.text}" already exists`);
      }

      // Add word
      words.push(word);
      index.textToId[normalizedText] = word.id;

      await Promise.all([setWords(words), setIndex(index)]);
    },

    async getAll(): Promise<StoredWord[]> {
      return getWords();
    },

    async exists(text: string): Promise<boolean> {
      const index = await getIndex();
      return !!index.textToId[text.toLowerCase()];
    },

    async delete(id: string): Promise<void> {
      const words = await getWords();
      const wordToDelete = words.find((w) => w.id === id);

      if (!wordToDelete) {
        return;
      }

      const filtered = words.filter((w) => w.id !== id);
      await setWords(filtered);

      // Update index
      const index = await getIndex();
      delete index.textToId[wordToDelete.text.toLowerCase()];
      await setIndex(index);
    },

    async clear(): Promise<void> {
      await chrome.storage.local.remove([STORAGE_KEY, INDEX_KEY]);
    },

    async getInfo(): Promise<{ count: number; sizeBytes?: number }> {
      const words = await getWords();

      // Try to get storage size (may not be available in all contexts)
      let sizeBytes: number | undefined;
      try {
        const bytesInUse = await chrome.storage.local.getBytesInUse([
          STORAGE_KEY,
          INDEX_KEY,
        ]);
        sizeBytes = bytesInUse;
      } catch {
        // getBytesInUse not available
      }

      return { count: words.length, sizeBytes };
    },
  };
}

/**
 * Export words to JSON file for backup/sync
 */
export async function exportWords(): Promise<string> {
  const storage = createBrowserStorage();
  const words = await storage.getAll();
  return JSON.stringify(words, null, 2);
}

/**
 * Import words from JSON file
 */
export async function importWords(
  json: string,
  merge: boolean = true
): Promise<{ imported: number; skipped: number }> {
  const storage = createBrowserStorage();
  const newWords = JSON.parse(json) as StoredWord[];

  let imported = 0;
  let skipped = 0;

  if (!merge) {
    await storage.clear();
  }

  for (const word of newWords) {
    try {
      const exists = await storage.exists(word.text);
      if (exists && merge) {
        skipped++;
        continue;
      }
      await storage.save(word);
      imported++;
    } catch {
      skipped++;
    }
  }

  return { imported, skipped };
}
