import { createTranslationCache } from './cache';
import { createNativeMessenger } from './native-messenger';
import { createTranslator } from './translator';
import { createWordBookService, createWordEntry } from './wordbook';
import type { Translator, WordBookService, WordEntry, NativeMessenger, NativeMessage } from './types';
import { TranslatorError, getUserMessage } from './errors';

// === Global State ===

let translator: Translator;
let wordBook: WordBookService;
let nativeMessenger: NativeMessenger;
let isInitialized = false;

// === Initialization ===

async function initialize(): Promise<void> {
  if (isInitialized) return;

  // Create native messenger (background script can use sendNativeMessage directly)
  nativeMessenger = createNativeMessenger();
  const cache = createTranslationCache();

  translator = createTranslator(nativeMessenger, cache);
  wordBook = createWordBookService(nativeMessenger);

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
}

interface SaveWordMessage {
  type: 'SAVE_WORD';
  word: WordEntry;
}

interface CreateAndSaveWordMessage {
  type: 'CREATE_AND_SAVE_WORD';
  text: string;
  translation: string;
  sourceURL?: string;
}

interface NativeProxyMessage {
  type: 'NATIVE_MESSAGE';
  payload: NativeMessage;
}

type BackgroundMessage =
  | TranslateMessage
  | SaveWordMessage
  | CreateAndSaveWordMessage
  | NativeProxyMessage;

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
        const translation = await translator.translate(message.text);
        sendResponse({ success: true, translation });
        break;
      }

      case 'SAVE_WORD': {
        await wordBook.save(message.word);
        sendResponse({ success: true });
        break;
      }

      case 'CREATE_AND_SAVE_WORD': {
        const word = createWordEntry(
          message.text,
          message.translation,
          message.sourceURL
        );
        await wordBook.save(word);
        sendResponse({ success: true, word });
        break;
      }

      case 'NATIVE_MESSAGE': {
        // Proxy native messaging requests from content scripts
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
