/**
 * Export/Import Utilities
 *
 * Manual backup and restore functionality for word book data.
 */

import type { StoredWord } from '../backends/types';
import type { SyncData } from './types';
import { createSyncData, generateDeviceId, SYNC_DATA_VERSION } from './types';

export interface ExportOptions {
  /** Include metadata in export */
  includeMetadata?: boolean;
  /** Pretty print JSON */
  prettyPrint?: boolean;
  /** Filter words by date range */
  dateRange?: {
    from?: number;
    to?: number;
  };
  /** Filter words by tags */
  tags?: string[];
}

export interface ImportResult {
  success: boolean;
  imported: number;
  skipped: number;
  errors: string[];
}

/**
 * Export words to JSON string
 */
export function exportToJson(
  words: StoredWord[],
  options: ExportOptions = {}
): string {
  const {
    includeMetadata = true,
    prettyPrint = true,
    dateRange,
    tags,
  } = options;

  let filteredWords = [...words];

  // Apply date range filter
  if (dateRange) {
    if (dateRange.from) {
      filteredWords = filteredWords.filter((w) => w.createdAt >= dateRange.from!);
    }
    if (dateRange.to) {
      filteredWords = filteredWords.filter((w) => w.createdAt <= dateRange.to!);
    }
  }

  // Apply tag filter
  if (tags && tags.length > 0) {
    filteredWords = filteredWords.filter((w) =>
      w.tags.some((t) => tags.includes(t))
    );
  }

  if (includeMetadata) {
    const syncData = createSyncData(filteredWords, generateDeviceId());
    return JSON.stringify(syncData, null, prettyPrint ? 2 : 0);
  } else {
    return JSON.stringify(filteredWords, null, prettyPrint ? 2 : 0);
  }
}

/**
 * Parse and validate imported JSON
 */
export function parseImportData(json: string): StoredWord[] {
  const parsed = JSON.parse(json) as unknown;

  // Check if it's a SyncData object
  if (
    typeof parsed === 'object' &&
    parsed !== null &&
    'version' in parsed &&
    'words' in parsed
  ) {
    const syncData = parsed as SyncData;

    // Version check
    if (syncData.version > SYNC_DATA_VERSION) {
      throw new Error(
        `Import data version ${syncData.version} is newer than supported version ${SYNC_DATA_VERSION}`
      );
    }

    return validateWords(syncData.words);
  }

  // Check if it's a direct array of words
  if (Array.isArray(parsed)) {
    return validateWords(parsed);
  }

  throw new Error('Invalid import format: expected SyncData or word array');
}

/**
 * Validate word entries
 */
function validateWords(words: unknown[]): StoredWord[] {
  const validated: StoredWord[] = [];
  const errors: string[] = [];

  for (let i = 0; i < words.length; i++) {
    const word = words[i];

    if (typeof word !== 'object' || word === null) {
      errors.push(`Entry ${i}: not an object`);
      continue;
    }

    const w = word as Record<string, unknown>;

    // Required fields
    if (typeof w.text !== 'string' || !w.text.trim()) {
      errors.push(`Entry ${i}: missing or invalid 'text'`);
      continue;
    }

    if (typeof w.translation !== 'string') {
      errors.push(`Entry ${i}: missing or invalid 'translation'`);
      continue;
    }

    // Build validated word with defaults
    validated.push({
      id: typeof w.id === 'string' ? w.id : crypto.randomUUID(),
      text: w.text.trim(),
      translation: w.translation,
      source:
        w.source === 'webpage' || w.source === 'video' || w.source === 'screenshot'
          ? w.source
          : 'webpage',
      sourceURL: typeof w.sourceURL === 'string' ? w.sourceURL : undefined,
      sentence: typeof w.sentence === 'string' ? w.sentence : undefined,
      tags: Array.isArray(w.tags) ? w.tags.filter((t) => typeof t === 'string') : [],
      createdAt: typeof w.createdAt === 'number' ? w.createdAt : Date.now(),
    });
  }

  if (errors.length > 0 && validated.length === 0) {
    throw new Error(`All entries invalid:\n${errors.join('\n')}`);
  }

  return validated;
}

/**
 * Download JSON as file
 */
export function downloadJson(data: string, filename: string): void {
  const blob = new Blob([data], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

/**
 * Read file as text
 */
export function readFileAsText(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = (): void => resolve(reader.result as string);
    reader.onerror = (): void => reject(new Error('Failed to read file'));
    reader.readAsText(file);
  });
}

/**
 * Generate export filename with timestamp
 */
export function generateExportFilename(): string {
  const now = new Date();
  const timestamp = now.toISOString().replace(/[:.]/g, '-').slice(0, 19);
  return `translator-wordbook-${timestamp}.json`;
}
