import type {
  Translator,
  NativeMessenger,
  TranslationCache,
  TranslateResponse,
  TranslatePayload,
} from './types';
import { createError, ErrorCode } from './errors';

export interface TranslatorOptions {
  targetLanguage?: string;
  sourceLanguage?: string;
}

export function createTranslator(
  messenger: NativeMessenger,
  cache: TranslationCache,
  options: TranslatorOptions = {}
): Translator {
  const { targetLanguage = 'zh-Hans', sourceLanguage } = options;

  return {
    async translate(text: string): Promise<string> {
      const trimmedText = text.trim();

      if (!trimmedText) {
        throw createError(ErrorCode.TRANSLATION_EMPTY, 'Text is empty');
      }

      // Check cache first
      const cached = cache.get(trimmedText);
      if (cached) {
        return cached;
      }

      // Prepare payload
      const payload: TranslatePayload = {
        text: trimmedText,
        targetLanguage,
      };

      if (sourceLanguage) {
        payload.sourceLanguage = sourceLanguage;
      }

      // Send to native host
      const response = await messenger.send<TranslateResponse>({
        action: 'translate',
        payload,
      });

      if (!response.success) {
        throw createError(
          ErrorCode.TRANSLATION_FAILED,
          response.error || 'Translation failed'
        );
      }

      if (!response.translation) {
        throw createError(ErrorCode.TRANSLATION_EMPTY, 'Empty translation');
      }

      // Cache the result
      cache.set(trimmedText, response.translation);

      return response.translation;
    },
  };
}
