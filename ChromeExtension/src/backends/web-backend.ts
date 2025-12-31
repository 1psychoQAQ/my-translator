/**
 * Web Backend - Uses free web translation APIs
 * Works on any platform without native dependencies
 */

import type { TranslationBackend, TranslationResult } from './types';

// Language code mapping for different APIs
const LANG_MAP: Record<string, { mymemory: string; lingva: string }> = {
  'zh-Hans': { mymemory: 'zh-CN', lingva: 'zh' },
  'zh-Hant': { mymemory: 'zh-TW', lingva: 'zh_HANT' },
  en: { mymemory: 'en', lingva: 'en' },
  ja: { mymemory: 'ja', lingva: 'ja' },
  ko: { mymemory: 'ko', lingva: 'ko' },
  fr: { mymemory: 'fr', lingva: 'fr' },
  de: { mymemory: 'de', lingva: 'de' },
  es: { mymemory: 'es', lingva: 'es' },
};

function mapLang(lang: string, api: 'mymemory' | 'lingva'): string {
  return LANG_MAP[lang]?.[api] || lang;
}

interface MyMemoryResponse {
  responseStatus: number;
  responseData: {
    translatedText: string;
    match: number;
  };
  matches?: Array<{
    translation: string;
    quality: number;
  }>;
}

interface LingvaResponse {
  translation: string;
}

/**
 * MyMemory Translation API
 * Free tier: 1000 requests/day without API key
 * https://mymemory.translated.net/doc/spec.php
 */
async function translateWithMyMemory(
  text: string,
  targetLang: string,
  sourceLang: string
): Promise<TranslationResult> {
  const source = mapLang(sourceLang, 'mymemory');
  const target = mapLang(targetLang, 'mymemory');

  const params = new URLSearchParams({
    q: text,
    langpair: `${source}|${target}`,
  });

  const response = await fetch(
    `https://api.mymemory.translated.net/get?${params}`
  );

  if (!response.ok) {
    throw new Error(`MyMemory API error: ${response.status}`);
  }

  const data = (await response.json()) as MyMemoryResponse;

  if (data.responseStatus !== 200) {
    throw new Error(`MyMemory error: status ${data.responseStatus}`);
  }

  return {
    translation: data.responseData.translatedText,
  };
}

/**
 * Lingva Translate API
 * Open source Google Translate frontend
 * https://github.com/thedaviddelta/lingva-translate
 */
async function translateWithLingva(
  text: string,
  targetLang: string,
  sourceLang: string
): Promise<TranslationResult> {
  const source = mapLang(sourceLang, 'lingva');
  const target = mapLang(targetLang, 'lingva');

  // Public Lingva instances
  const instances = [
    'lingva.ml',
    'translate.plausibility.cloud',
    'lingva.lunar.icu',
  ];

  let lastError: Error | null = null;

  for (const instance of instances) {
    try {
      const url = `https://${instance}/api/v1/${source}/${target}/${encodeURIComponent(text)}`;
      const response = await fetch(url, {
        signal: AbortSignal.timeout(10000)
      });

      if (!response.ok) {
        continue;
      }

      const data = (await response.json()) as LingvaResponse;
      return { translation: data.translation };
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      continue;
    }
  }

  throw lastError || new Error('All Lingva instances failed');
}

export type WebApiProvider = 'mymemory' | 'lingva';

export function createWebBackend(
  provider: WebApiProvider = 'mymemory'
): TranslationBackend {
  return {
    id: `web-${provider}`,
    name: provider === 'mymemory' ? 'MyMemory API' : 'Lingva Translate',

    async translate(
      text: string,
      targetLang: string,
      sourceLang?: string,
      _context?: string
    ): Promise<TranslationResult> {
      const source = sourceLang || 'en';

      // Try primary provider first, fallback to other on failure
      try {
        if (provider === 'mymemory') {
          return await translateWithMyMemory(text, targetLang, source);
        } else {
          return await translateWithLingva(text, targetLang, source);
        }
      } catch (primaryError) {
        // Fallback to other provider
        try {
          if (provider === 'mymemory') {
            return await translateWithLingva(text, targetLang, source);
          } else {
            return await translateWithMyMemory(text, targetLang, source);
          }
        } catch {
          // Throw original error if both fail
          throw primaryError;
        }
      }
    },

    async isAvailable(): Promise<boolean> {
      try {
        // Quick ping to check if API is reachable
        const result = await this.translate('test', 'zh-Hans', 'en');
        return !!result.translation;
      } catch {
        return false;
      }
    },

    // Web TTS using browser's built-in speech synthesis
    async speak(text: string, language?: string): Promise<void> {
      return new Promise((resolve, reject) => {
        if (!('speechSynthesis' in window)) {
          reject(new Error('Speech synthesis not supported'));
          return;
        }

        const utterance = new SpeechSynthesisUtterance(text);
        utterance.lang = language || 'en-US';
        utterance.rate = 0.9;
        utterance.onend = (): void => resolve();
        utterance.onerror = (e): void => reject(new Error(e.error));

        window.speechSynthesis.speak(utterance);
      });
    },
  };
}
