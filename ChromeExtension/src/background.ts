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
let isNativeConnected = false;

// === Initialization ===

async function initialize(): Promise<void> {
  if (isInitialized) return;

  // Create native messenger (background script can use sendNativeMessage directly)
  nativeMessenger = createNativeMessenger();
  const cache = createTranslationCache();

  // Check if native host is connected
  try {
    isNativeConnected = await nativeMessenger.isConnected();
  } catch {
    isNativeConnected = false;
  }

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

interface TranslatePageMessage {
  type: 'TRANSLATE_PAGE';
}

interface TranslateSelectionMessage {
  type: 'TRANSLATE_SELECTION';
}

interface RestorePageMessage {
  type: 'RESTORE_PAGE';
}

interface ToggleYouTubeSubtitleMessage {
  type: 'TOGGLE_YOUTUBE_SUBTITLE';
}

interface NativeProxyMessage {
  type: 'NATIVE_MESSAGE';
  payload: NativeMessage;
}

type BackgroundMessage =
  | TranslateMessage
  | SaveWordMessage
  | CreateAndSaveWordMessage
  | TranslatePageMessage
  | TranslateSelectionMessage
  | RestorePageMessage
  | ToggleYouTubeSubtitleMessage
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

      case 'TRANSLATE_PAGE':
      case 'TRANSLATE_SELECTION':
      case 'RESTORE_PAGE':
      case 'TOGGLE_YOUTUBE_SUBTITLE': {
        // Forward to active tab's content script
        const [tab] = await chrome.tabs.query({
          active: true,
          currentWindow: true,
        });
        if (tab?.id) {
          chrome.tabs.sendMessage(tab.id, message, sendResponse);
        } else {
          sendResponse({ success: false, error: 'No active tab' });
        }
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

// === Extension Icon Click Handler ===

chrome.action.onClicked.addListener(async (tab) => {
  if (!tab.id) return;

  // Send message to content script to translate page
  try {
    await chrome.tabs.sendMessage(tab.id, { type: 'TRANSLATE_PAGE' });
  } catch {
    // Content script might not be loaded yet
    console.error('[Translator Background] Failed to send message to tab');
  }
});

// === Context Menu (Right-click) ===

chrome.runtime.onInstalled.addListener(() => {
  // Remove existing context menus first to avoid duplicates
  chrome.contextMenus.removeAll(() => {
    // Create context menu for selected text
    chrome.contextMenus.create({
      id: 'translate-selection',
      title: '翻译选中文本',
      contexts: ['selection'],
    });

    chrome.contextMenus.create({
      id: 'translate-page',
      title: '翻译整个页面',
      contexts: ['page'],
    });

    chrome.contextMenus.create({
      id: 'restore-page',
      title: '恢复原文',
      contexts: ['page'],
    });

    // YouTube-specific context menu
    chrome.contextMenus.create({
      id: 'toggle-youtube-subtitle',
      title: '切换双语字幕',
      contexts: ['page'],
      documentUrlPatterns: ['*://www.youtube.com/*', '*://youtube.com/*'],
    });
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (!tab?.id) return;

  if (info.menuItemId === 'translate-selection') {
    try {
      await chrome.tabs.sendMessage(tab.id, { type: 'TRANSLATE_SELECTION' });
    } catch {
      console.error('[Translator Background] Failed to translate selection');
    }
  }

  if (info.menuItemId === 'translate-page') {
    try {
      await chrome.tabs.sendMessage(tab.id, { type: 'TRANSLATE_PAGE' });
    } catch {
      console.error('[Translator Background] Failed to translate page');
    }
  }

  if (info.menuItemId === 'restore-page') {
    try {
      await chrome.tabs.sendMessage(tab.id, { type: 'RESTORE_PAGE' });
    } catch {
      console.error('[Translator Background] Failed to restore page');
    }
  }

  if (info.menuItemId === 'toggle-youtube-subtitle') {
    try {
      await chrome.tabs.sendMessage(tab.id, { type: 'TOGGLE_YOUTUBE_SUBTITLE' });
    } catch {
      console.error('[Translator Background] Failed to toggle YouTube subtitle');
    }
  }
});

// Export for potential testing
export { initialize, handleMessage };
