/**
 * Translation Backend Abstraction Layer
 * Allows the extension to work with different translation providers
 */

export type BackendMode = 'native' | 'web' | 'auto';

export interface TranslationResult {
  translation: string;
  detectedLanguage?: string;
}

export interface TranslationBackend {
  /** Unique identifier for this backend */
  readonly id: string;

  /** Human-readable name */
  readonly name: string;

  /** Translate text */
  translate(
    text: string,
    targetLang: string,
    sourceLang?: string,
    context?: string
  ): Promise<TranslationResult>;

  /** Check if backend is available */
  isAvailable(): Promise<boolean>;

  /** Text-to-speech (optional) */
  speak?(text: string, language?: string): Promise<void>;
}

export interface WordStorage {
  /** Save a word entry */
  save(word: StoredWord): Promise<void>;

  /** Get all words */
  getAll(): Promise<StoredWord[]>;

  /** Check if word exists */
  exists(text: string): Promise<boolean>;

  /** Delete a word */
  delete(id: string): Promise<void>;

  /** Clear all words */
  clear(): Promise<void>;

  /** Get storage info */
  getInfo(): Promise<{ count: number; sizeBytes?: number }>;
}

export interface StoredWord {
  id: string;
  text: string;
  translation: string;
  source: 'webpage' | 'video' | 'screenshot';
  sourceURL?: string;
  sentence?: string;
  tags: string[];
  createdAt: number;
}

export interface ExtensionConfig {
  mode: BackendMode;
  targetLanguage: string;
  sourceLanguage?: string;
  webApiProvider?: 'mymemory' | 'lingva';
}
