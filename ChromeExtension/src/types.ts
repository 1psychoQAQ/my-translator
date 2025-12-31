// === Data Models ===

export interface WordEntry {
  id: string;
  text: string;
  translation: string;
  source: 'webpage' | 'video' | 'screenshot';
  sourceURL?: string;
  sentence?: string; // 完整句子，用于语境回顾
  tags: string[];
  createdAt: number;
  syncedAt?: number;
}

// === Service Interfaces (for DI) ===

export interface Translator {
  translate(text: string, context?: string): Promise<string>;
}

export interface WordBookService {
  save(word: WordEntry): Promise<void>;
  exists(text: string): Promise<boolean>;
}

export interface NativeMessenger {
  send<T>(message: NativeMessage): Promise<T>;
  isConnected(): Promise<boolean>;
}

export interface TranslationCache {
  get(text: string): string | null;
  set(text: string, translation: string): void;
  clear(): void;
}

// === Message Types ===

export type NativeMessageAction = 'translate' | 'saveWord' | 'speak' | 'ping';

export interface NativeMessage {
  action: NativeMessageAction;
  payload: unknown;
}

export interface TranslatePayload {
  text: string;
  sourceLanguage?: string;
  targetLanguage: string;
  context?: string; // 上下文句子，用于语境翻译
}

export interface SpeakPayload {
  text: string;
  language?: string; // 默认 en-US
}

export interface TranslateResponse {
  success: boolean;
  translation?: string;
  error?: string;
}

export interface SaveWordResponse {
  success: boolean;
  error?: string;
}

export interface PingResponse {
  success: boolean;
  version?: string;
}

// === Content Script Messages ===

export type ContentMessageType =
  | 'TRANSLATE_TEXT'
  | 'SAVE_WORD'
  | 'CHECK_CONNECTION';

export interface ContentMessage {
  type: ContentMessageType;
  payload: unknown;
}

// === UI Types ===

export interface ToastNotification {
  success(message: string): void;
  error(message: string): void;
  info(message: string): void;
}
