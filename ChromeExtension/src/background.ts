import { createTranslationCache } from './cache';
import { createBackendManager, type BackendManager, type StoredWord, type ExtensionConfig } from './backends';
import { createNativeMessenger } from './native-messenger';
import type { NativeMessenger, NativeMessage } from './types';
import { TranslatorError, getUserMessage } from './errors';
import {
  createGistSyncService,
  exportToJson,
  parseImportData,
  type SyncService,
  type SyncConfig,
} from './sync';

// === Global State ===

let backendManager: BackendManager;
let nativeMessenger: NativeMessenger;
let syncService: SyncService;
const translationCache = createTranslationCache();
let isInitialized = false;

// === Initialization ===

async function initialize(): Promise<void> {
  if (isInitialized) return;

  // Create backend manager for cross-platform support
  backendManager = createBackendManager();
  await backendManager.initialize();

  // Native messenger for direct native messaging (legacy support)
  nativeMessenger = createNativeMessenger();

  // Sync service for cloud backup
  syncService = createGistSyncService();

  console.log(
    `[Translator] Initialized with ${backendManager.resolvedMode} backend`
  );

  isInitialized = true;
}

// Ensure initialization on startup
initialize().catch((error) => {
  console.error('[Translator Background] Failed to initialize:', error);
});

// === Message Handler ===

interface TranslateMessage {
  type: 'TRANSLATE';
  text: string;
  context?: string;
}

interface SaveWordMessage {
  type: 'SAVE_WORD';
  word: StoredWord;
}

interface CreateAndSaveWordMessage {
  type: 'CREATE_AND_SAVE_WORD';
  text: string;
  translation: string;
  sourceURL?: string;
  sentence?: string;
}

interface SpeakMessage {
  type: 'SPEAK';
  text: string;
  language?: string;
}

interface NativeProxyMessage {
  type: 'NATIVE_MESSAGE';
  payload: NativeMessage;
}

interface GetConfigMessage {
  type: 'GET_CONFIG';
}

interface SetConfigMessage {
  type: 'SET_CONFIG';
  config: Partial<ExtensionConfig>;
}

interface GetBackendInfoMessage {
  type: 'GET_BACKEND_INFO';
}

interface GetWordsMessage {
  type: 'GET_WORDS';
}

interface ExportWordsMessage {
  type: 'EXPORT_WORDS';
}

interface ImportWordsMessage {
  type: 'IMPORT_WORDS';
  json: string;
  merge?: boolean;
}

interface SyncConfigureMessage {
  type: 'SYNC_CONFIGURE';
  config: SyncConfig;
}

interface SyncStatusMessage {
  type: 'SYNC_STATUS';
}

interface SyncNowMessage {
  type: 'SYNC_NOW';
}

interface SyncDisconnectMessage {
  type: 'SYNC_DISCONNECT';
}

type BackgroundMessage =
  | TranslateMessage
  | SaveWordMessage
  | CreateAndSaveWordMessage
  | SpeakMessage
  | NativeProxyMessage
  | GetConfigMessage
  | SetConfigMessage
  | GetBackendInfoMessage
  | GetWordsMessage
  | ExportWordsMessage
  | ImportWordsMessage
  | SyncConfigureMessage
  | SyncStatusMessage
  | SyncNowMessage
  | SyncDisconnectMessage;

chrome.runtime.onMessage.addListener(
  (
    message: BackgroundMessage,
    _sender: chrome.runtime.MessageSender,
    sendResponse: (response: unknown) => void
  ) => {
    // Ensure initialized
    if (!isInitialized) {
      initialize()
        .then(() => handleMessage(message, sendResponse))
        .catch((error: Error) => {
          sendResponse({ success: false, error: error.message });
        });
      return true;
    }

    handleMessage(message, sendResponse);
    return true; // Keep channel open for async response
  }
);

async function handleMessage(
  message: BackgroundMessage,
  sendResponse: (response: unknown) => void
): Promise<void> {
  try {
    switch (message.type) {
      case 'TRANSLATE': {
        // Check cache first
        const cacheKey = message.context
          ? `${message.text}::${message.context}`
          : message.text;
        const cached = translationCache.get(cacheKey);
        if (cached) {
          sendResponse({ success: true, translation: cached });
          return;
        }

        const translation = await backendManager.translate(
          message.text,
          message.context
        );

        // Cache the result
        translationCache.set(cacheKey, translation);

        sendResponse({ success: true, translation });
        break;
      }

      case 'SAVE_WORD': {
        await backendManager.saveWord(message.word);
        sendResponse({ success: true });
        break;
      }

      case 'CREATE_AND_SAVE_WORD': {
        const word: StoredWord = {
          id: crypto.randomUUID(),
          text: message.text.trim(),
          translation: message.translation,
          source: 'webpage',
          sourceURL: message.sourceURL,
          sentence: message.sentence,
          tags: [],
          createdAt: Date.now(),
        };
        await backendManager.saveWord(word);
        sendResponse({ success: true, word });
        break;
      }

      case 'SPEAK': {
        await backendManager.speak(message.text, message.language);
        sendResponse({ success: true });
        break;
      }

      case 'NATIVE_MESSAGE': {
        // Proxy native messaging requests (for backward compatibility)
        try {
          const response = await nativeMessenger.send(message.payload);
          sendResponse({ success: true, data: response });
        } catch (error) {
          if (error instanceof TranslatorError) {
            sendResponse({ success: false, error: getUserMessage(error.code) });
          } else if (error instanceof Error) {
            sendResponse({ success: false, error: error.message });
          } else {
            sendResponse({ success: false, error: 'Native message failed' });
          }
        }
        break;
      }

      case 'GET_CONFIG': {
        const config = await backendManager.getConfig();
        sendResponse({ success: true, config });
        break;
      }

      case 'SET_CONFIG': {
        await backendManager.setConfig(message.config);
        // Clear cache when config changes
        translationCache.clear();
        sendResponse({ success: true });
        break;
      }

      case 'GET_BACKEND_INFO': {
        const nativeAvailable = await backendManager.isNativeAvailable();
        sendResponse({
          success: true,
          info: {
            mode: backendManager.mode,
            resolvedMode: backendManager.resolvedMode,
            backendId: backendManager.backend.id,
            backendName: backendManager.backend.name,
            nativeAvailable,
          },
        });
        break;
      }

      case 'GET_WORDS': {
        const words = await backendManager.storage.getAll();
        sendResponse({ success: true, words });
        break;
      }

      case 'EXPORT_WORDS': {
        const words = await backendManager.storage.getAll();
        const json = exportToJson(words, { includeMetadata: true });
        sendResponse({ success: true, json });
        break;
      }

      case 'IMPORT_WORDS': {
        const importedWords = parseImportData(message.json);
        let imported = 0;
        let skipped = 0;

        for (const word of importedWords) {
          try {
            const exists = await backendManager.storage.exists(word.text);
            if (exists && message.merge !== false) {
              skipped++;
              continue;
            }
            await backendManager.storage.save(word);
            imported++;
          } catch {
            skipped++;
          }
        }

        sendResponse({ success: true, imported, skipped });
        break;
      }

      case 'SYNC_CONFIGURE': {
        await syncService.configure(message.config);
        sendResponse({ success: true });
        break;
      }

      case 'SYNC_STATUS': {
        const configured = await syncService.isConfigured();
        sendResponse({
          success: true,
          status: {
            configured,
            provider: syncService.provider,
          },
        });
        break;
      }

      case 'SYNC_NOW': {
        const words = await backendManager.storage.getAll();
        const result = await syncService.sync(words);

        // If sync added new words, save them to local storage
        if (result.success && result.added > 0) {
          const remoteData = await syncService.pull();
          if (remoteData) {
            for (const word of remoteData.words) {
              const exists = await backendManager.storage.exists(word.text);
              if (!exists) {
                await backendManager.storage.save(word);
              }
            }
          }
        }

        sendResponse({ success: result.success, result });
        break;
      }

      case 'SYNC_DISCONNECT': {
        await syncService.disconnect();
        sendResponse({ success: true });
        break;
      }

      default: {
        sendResponse({ success: false, error: 'Unknown message type' });
      }
    }
  } catch (error) {
    if (error instanceof TranslatorError) {
      sendResponse({
        success: false,
        error: getUserMessage(error.code),
        code: error.code,
      });
    } else if (error instanceof Error) {
      sendResponse({ success: false, error: error.message });
    } else {
      sendResponse({ success: false, error: 'Unknown error' });
    }
  }
}

// Export for potential testing
export { initialize, handleMessage };
