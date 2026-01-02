/**
 * Backend Manager - Handles mode detection and switching
 */

import type {
  TranslationBackend,
  WordStorage,
  BackendMode,
  ExtensionConfig,
  StoredWord,
} from './types';
import { createNativeBackend } from './native-backend';
import { createWebBackend } from './web-backend';
import { createBrowserStorage } from './browser-storage';
import type { NativeMessenger } from '../types';
import { createNativeMessenger } from '../native-messenger';
import { speak as webSpeak } from '../speech';

const CONFIG_KEY = 'translator_config';

export interface BackendManager {
  /** Current active backend */
  readonly backend: TranslationBackend;

  /** Word storage (browser-based, cross-platform) */
  readonly storage: WordStorage;

  /** Current mode */
  readonly mode: BackendMode;

  /** Actual resolved mode ('native' or 'web') */
  readonly resolvedMode: 'native' | 'web';

  /** Initialize and detect best backend */
  initialize(): Promise<void>;

  /** Translate text */
  translate(text: string, context?: string): Promise<string>;

  /** Save word to storage */
  saveWord(word: StoredWord): Promise<void>;

  /** Text-to-speech */
  speak(text: string, language?: string): Promise<void>;

  /** Get configuration */
  getConfig(): Promise<ExtensionConfig>;

  /** Update configuration */
  setConfig(config: Partial<ExtensionConfig>): Promise<void>;

  /** Check if native backend is available */
  isNativeAvailable(): Promise<boolean>;
}

const DEFAULT_CONFIG: ExtensionConfig = {
  mode: 'auto',
  targetLanguage: 'zh-Hans',
  webApiProvider: 'mymemory',
};

async function loadConfig(): Promise<ExtensionConfig> {
  try {
    const result = await chrome.storage.local.get(CONFIG_KEY);
    const stored = result[CONFIG_KEY] as Partial<ExtensionConfig> | undefined;
    return { ...DEFAULT_CONFIG, ...stored };
  } catch {
    return { ...DEFAULT_CONFIG };
  }
}

async function saveConfig(config: ExtensionConfig): Promise<void> {
  await chrome.storage.local.set({ [CONFIG_KEY]: config });
}

export function createBackendManager(): BackendManager {
  let currentBackend: TranslationBackend | null = null;
  let currentMode: BackendMode = 'auto';
  let resolvedMode: 'native' | 'web' = 'web';
  let config: ExtensionConfig = { ...DEFAULT_CONFIG };

  const storage = createBrowserStorage();
  const nativeBackend = createNativeBackend();
  let webBackend = createWebBackend(config.webApiProvider || 'mymemory');

  // Native messenger for saving to macOS SwiftData when available
  let nativeMessenger: NativeMessenger | null = null;

  function getNativeMessenger(): NativeMessenger {
    if (!nativeMessenger) {
      nativeMessenger = createNativeMessenger();
    }
    return nativeMessenger;
  }

  const manager: BackendManager = {
    get backend(): TranslationBackend {
      if (!currentBackend) {
        throw new Error('Backend not initialized');
      }
      return currentBackend;
    },

    get storage(): WordStorage {
      return storage;
    },

    get mode(): BackendMode {
      return currentMode;
    },

    get resolvedMode(): 'native' | 'web' {
      return resolvedMode;
    },

    async initialize(): Promise<void> {
      config = await loadConfig();
      currentMode = config.mode;

      // Recreate web backend with correct provider
      webBackend = createWebBackend(config.webApiProvider || 'mymemory');

      if (currentMode === 'native') {
        // Force native mode
        const available = await nativeBackend.isAvailable();
        if (available) {
          currentBackend = nativeBackend;
          resolvedMode = 'native';
        } else {
          // Fall back to web if native not available
          console.warn(
            '[BackendManager] Native mode requested but not available, falling back to web'
          );
          currentBackend = webBackend;
          resolvedMode = 'web';
        }
      } else if (currentMode === 'web') {
        // Force web mode
        currentBackend = webBackend;
        resolvedMode = 'web';
      } else {
        // Auto mode: prefer native, fall back to web
        const nativeAvailable = await nativeBackend.isAvailable();
        if (nativeAvailable) {
          currentBackend = nativeBackend;
          resolvedMode = 'native';
          console.log('[BackendManager] Auto-detected native backend');
        } else {
          currentBackend = webBackend;
          resolvedMode = 'web';
          console.log('[BackendManager] Using web backend');
        }
      }
    },

    async translate(text: string, context?: string): Promise<string> {
      const result = await this.backend.translate(
        text,
        config.targetLanguage,
        config.sourceLanguage,
        context
      );
      return result.translation;
    },

    async saveWord(word: StoredWord): Promise<void> {
      // Always save to browser storage (cross-platform)
      await storage.save(word);

      // Also save to native SwiftData if available
      if (resolvedMode === 'native') {
        try {
          await getNativeMessenger().send({
            action: 'saveWord',
            payload: word,
          });
        } catch (error) {
          // Log but don't fail - browser storage is primary
          console.warn(
            '[BackendManager] Failed to sync to native storage:',
            error
          );
        }
      }
    },

    async speak(text: string, language?: string): Promise<void> {
      // 始终使用 Web Speech API，零延迟，无 Dock 图标
      webSpeak(text, language);
    },

    async getConfig(): Promise<ExtensionConfig> {
      return { ...config };
    },

    async setConfig(newConfig: Partial<ExtensionConfig>): Promise<void> {
      config = { ...config, ...newConfig };
      await saveConfig(config);

      // Re-initialize if mode changed
      if (newConfig.mode !== undefined || newConfig.webApiProvider !== undefined) {
        await this.initialize();
      }
    },

    async isNativeAvailable(): Promise<boolean> {
      return nativeBackend.isAvailable();
    },
  };

  return manager;
}
