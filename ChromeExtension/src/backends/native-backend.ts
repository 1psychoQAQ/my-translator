/**
 * Native Backend - Uses macOS Native Messaging
 * Only works on macOS with TranslatorApp installed
 */

import type {
  TranslationBackend,
  TranslationResult,
} from './types';
import type { NativeMessenger, TranslateResponse } from '../types';
import { createNativeMessenger } from '../native-messenger';

export function createNativeBackend(): TranslationBackend {
  let messenger: NativeMessenger | null = null;

  function getMessenger(): NativeMessenger {
    if (!messenger) {
      messenger = createNativeMessenger();
    }
    return messenger;
  }

  return {
    id: 'native',
    name: 'macOS Native (Apple Translation)',

    async translate(
      text: string,
      targetLang: string,
      sourceLang?: string,
      context?: string
    ): Promise<TranslationResult> {
      const response = await getMessenger().send<TranslateResponse>({
        action: 'translate',
        payload: {
          text,
          targetLanguage: targetLang,
          sourceLanguage: sourceLang,
          context,
        },
      });

      if (!response.success || !response.translation) {
        throw new Error(response.error || 'Translation failed');
      }

      return { translation: response.translation };
    },

    async isAvailable(): Promise<boolean> {
      try {
        return await getMessenger().isConnected();
      } catch {
        return false;
      }
    },

    async speak(text: string, language?: string): Promise<void> {
      await getMessenger().send({
        action: 'speak',
        payload: { text, language: language || 'en-US' },
      });
    },
  };
}
