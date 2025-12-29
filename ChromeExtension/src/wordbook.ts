import type {
  WordBookService,
  NativeMessenger,
  WordEntry,
  SaveWordResponse,
} from './types';
import { createError, ErrorCode } from './errors';

export function createWordBookService(
  messenger: NativeMessenger
): WordBookService {
  // Local dedup set (session only, case-insensitive)
  const savedWords = new Set<string>();

  function normalizeText(text: string): string {
    return text.trim().toLowerCase();
  }

  return {
    async save(word: WordEntry): Promise<void> {
      const normalizedText = normalizeText(word.text);

      // Check local dedup
      if (savedWords.has(normalizedText)) {
        throw createError(
          ErrorCode.WORD_ALREADY_EXISTS,
          `Word "${word.text}" already saved`
        );
      }

      const response = await messenger.send<SaveWordResponse>({
        action: 'saveWord',
        payload: word,
      });

      if (!response.success) {
        throw createError(
          ErrorCode.SAVE_WORD_FAILED,
          response.error || 'Failed to save word'
        );
      }

      // Add to local dedup set
      savedWords.add(normalizedText);
    },

    async exists(text: string): Promise<boolean> {
      const normalizedText = normalizeText(text);
      return savedWords.has(normalizedText);
    },
  };
}

export function createWordEntry(
  text: string,
  translation: string,
  sourceURL?: string
): WordEntry {
  return {
    id: crypto.randomUUID(),
    text: text.trim(),
    translation,
    source: 'webpage',
    sourceURL,
    tags: [],
    createdAt: Date.now(),
  };
}
