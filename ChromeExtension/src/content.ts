import { createTranslationCache } from './cache';
import { createMessengerWithFallback } from './native-messenger';
import { createTranslator } from './translator';
import { createWordBookService, createWordEntry } from './wordbook';
import { createToast } from './toast';
import { TranslatorError, ErrorCode, getUserMessage } from './errors';
import type { Translator, WordBookService, ToastNotification } from './types';

// === Constants ===

const TRANSLATION_CONTAINER_CLASS = 'translator-bilingual-container';
const WORD_POPUP_ID = 'translator-word-popup';

// === Global State ===

let translator: Translator;
let wordBook: WordBookService;
let toast: ToastNotification;
let isInitialized = false;

// === Initialization ===

async function initialize(): Promise<void> {
  if (isInitialized) return;

  const messenger = await createMessengerWithFallback();
  const cache = createTranslationCache();

  translator = createTranslator(messenger, cache);
  wordBook = createWordBookService(messenger);
  toast = createToast();

  isInitialized = true;

  // Set up event listeners
  setupDoubleClickHandler();
  injectStyles();
}

// === Styles Injection ===

function injectStyles(): void {
  // No global styles needed - all styling is done inline via Shadow DOM
}

// === Bilingual Display ===

function escapeHtml(text: string): string {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function injectTranslation(element: HTMLElement, translation: string): void {
  // Remove existing translation if any
  removeTranslation(element);

  // Get background from the element
  const { bg, textColor, isDark } = getElementBackground(element);
  const borderColor = isDark ? 'rgba(255, 255, 255, 0.3)' : 'rgba(74, 144, 217, 0.5)';

  // Create container
  const container = document.createElement('div');
  container.className = TRANSLATION_CONTAINER_CLASS;
  container.setAttribute('data-source-id', element.dataset.translatorId || '');

  // Use Shadow DOM for isolation
  const shadowRoot = container.attachShadow({ mode: 'closed' });
  shadowRoot.innerHTML = `
    <style>
      :host {
        all: initial;
        display: block;
        margin-top: 6px;
        padding: 8px 12px;
        background: ${bg};
        border-left: 3px solid ${borderColor};
        border-radius: 4px;
      }
      .translation {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
        font-size: 0.95em;
        line-height: 1.6;
        color: ${textColor};
        opacity: 0.85;
        white-space: pre-wrap;
        word-break: break-word;
      }
    </style>
    <div class="translation">${escapeHtml(translation)}</div>
  `;

  // Insert after the original element
  element.insertAdjacentElement('afterend', container);

  // Mark element as translated
  element.dataset.translated = 'true';
}

function removeTranslation(element: HTMLElement): void {
  const next = element.nextElementSibling;
  if (next?.classList.contains(TRANSLATION_CONTAINER_CLASS)) {
    next.remove();
  }
  delete element.dataset.translated;
}

// Remove all translations from the page
function removeAllTranslations(): void {
  // Remove all translation containers
  const containers = document.querySelectorAll(`.${TRANSLATION_CONTAINER_CLASS}`);
  containers.forEach((container) => container.remove());

  // Clear translated markers from all elements
  const translatedElements = document.querySelectorAll('[data-translated="true"]');
  translatedElements.forEach((element) => {
    delete (element as HTMLElement).dataset.translated;
  });
}

// === Word Popup ===

function getElementBackground(element: Element): { bg: string; textColor: string; isDark: boolean } {
  let el: Element | null = element;
  while (el) {
    const style = window.getComputedStyle(el);
    const bg = style.backgroundColor;
    // Check if background is not transparent
    if (bg && bg !== 'transparent' && bg !== 'rgba(0, 0, 0, 0)') {
      // Parse RGB to determine if dark
      const match = bg.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
      if (match) {
        const [, r, g, b] = match.map(Number);
        const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
        const isDark = luminance < 0.5;
        return {
          bg,
          textColor: isDark ? '#fff' : '#222',
          isDark
        };
      }
      return { bg, textColor: '#222', isDark: false };
    }
    el = el.parentElement;
  }
  return { bg: '#ffffff', textColor: '#222', isDark: false };
}

function showWordPopup(
  x: number,
  y: number,
  originalText: string,
  translation: string,
  onSave: () => void,
  targetElement?: Element
): void {
  removeWordPopup();

  // Get background from target element
  const { bg, textColor, isDark } = targetElement
    ? getElementBackground(targetElement)
    : { bg: '#ffffff', textColor: '#222', isDark: false };

  const popup = document.createElement('div');
  popup.id = WORD_POPUP_ID;
  popup.style.cssText = 'position: fixed; z-index: 2147483647; pointer-events: none;';

  // Adjust position to stay within viewport
  const viewportWidth = window.innerWidth;
  const viewportHeight = window.innerHeight;
  const popupWidth = 260;
  const popupHeight = 100;

  let posX = x + 10;
  let posY = y + 10;

  if (posX + popupWidth > viewportWidth) {
    posX = x - popupWidth - 10;
  }
  if (posY + popupHeight > viewportHeight) {
    posY = y - popupHeight - 10;
  }

  const borderColor = isDark ? 'rgba(255, 255, 255, 0.2)' : 'rgba(0, 0, 0, 0.1)';
  const subtextColor = isDark ? 'rgba(255, 255, 255, 0.6)' : '#888';
  const closeBtnBg = isDark ? 'rgba(255, 255, 255, 0.15)' : '#f0f0f0';
  const closeBtnHover = isDark ? 'rgba(255, 255, 255, 0.25)' : '#e0e0e0';
  const closeBtnColor = isDark ? 'rgba(255, 255, 255, 0.8)' : '#555';

  const shadow = popup.attachShadow({ mode: 'closed' });
  shadow.innerHTML = `
    <style>
      :host {
        all: initial;
        position: fixed !important;
        left: 0 !important;
        top: 0 !important;
        width: 0 !important;
        height: 0 !important;
        overflow: visible !important;
        background: transparent !important;
      }
      .popup {
        position: fixed;
        left: ${posX}px;
        top: ${posY}px;
        z-index: 2147483647;
        background: ${bg};
        border: 1px solid ${borderColor};
        border-radius: 8px;
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
        padding: 12px 16px;
        max-width: 260px;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
        pointer-events: auto;
        animation: popupFadeIn 0.15s ease-out;
      }
      @keyframes popupFadeIn {
        from { opacity: 0; transform: translateY(-4px); }
        to { opacity: 1; transform: translateY(0); }
      }
      .original {
        font-size: 12px;
        color: ${subtextColor};
        margin-bottom: 4px;
        word-break: break-word;
      }
      .translation {
        font-size: 15px;
        color: ${textColor};
        font-weight: 500;
        margin-bottom: 10px;
        word-break: break-word;
        line-height: 1.4;
      }
      .actions {
        display: flex;
        gap: 8px;
      }
      button {
        padding: 6px 14px;
        border: none;
        border-radius: 5px;
        cursor: pointer;
        font-size: 12px;
        font-weight: 500;
        transition: background 0.15s;
      }
      .save-btn {
        background: #007aff;
        color: white;
      }
      .save-btn:hover {
        background: #0056b3;
      }
      .close-btn {
        background: ${closeBtnBg};
        color: ${closeBtnColor};
      }
      .close-btn:hover {
        background: ${closeBtnHover};
      }
    </style>
    <div class="popup">
      <div class="original">${escapeHtml(originalText)}</div>
      <div class="translation">${escapeHtml(translation)}</div>
      <div class="actions">
        <button class="save-btn">收藏</button>
        <button class="close-btn">关闭</button>
      </div>
    </div>
  `;

  document.body.appendChild(popup);

  // Event handlers
  const saveBtn = shadow.querySelector('.save-btn');
  const closeBtn = shadow.querySelector('.close-btn');

  saveBtn?.addEventListener('click', () => {
    onSave();
    removeWordPopup();
  });

  closeBtn?.addEventListener('click', removeWordPopup);

  // Close on click outside (with delay to prevent immediate close)
  setTimeout(() => {
    document.addEventListener('click', handleOutsideClick);
  }, 100);

  function handleOutsideClick(e: MouseEvent): void {
    if (!popup.contains(e.target as Node)) {
      removeWordPopup();
      document.removeEventListener('click', handleOutsideClick);
    }
  }

  // Close on Escape key
  function handleEscape(e: KeyboardEvent): void {
    if (e.key === 'Escape') {
      removeWordPopup();
      document.removeEventListener('keydown', handleEscape);
    }
  }
  document.addEventListener('keydown', handleEscape);
}

function removeWordPopup(): void {
  document.getElementById(WORD_POPUP_ID)?.remove();
}

// === Double-click Word Selection Handler ===

function setupDoubleClickHandler(): void {
  document.addEventListener('dblclick', handleDoubleClick);
}

async function handleDoubleClick(event: MouseEvent): Promise<void> {
  const selection = window.getSelection();
  const selectedText = selection?.toString().trim();

  if (!selectedText || selectedText.length === 0) return;

  // Limit to reasonable word/phrase length (max 100 chars, max 10 words)
  if (selectedText.length > 100) return;
  if (selectedText.split(/\s+/).length > 10) return;

  // Don't handle if clicking on our own elements
  const target = event.target as HTMLElement;
  if (
    target.closest(`#${WORD_POPUP_ID}`) ||
    target.closest(`.${TRANSLATION_CONTAINER_CLASS}`)
  ) {
    return;
  }

  try {
    const translation = await translator.translate(selectedText);

    showWordPopup(
      event.clientX,
      event.clientY,
      selectedText,
      translation,
      async () => {
        // Save to word book when user clicks save
        try {
          const word = createWordEntry(
            selectedText,
            translation,
            window.location.href
          );
          console.log('[Translator] Saving word:', word);
          await wordBook.save(word);
          console.log('[Translator] Word saved successfully');
          toast.success('已收藏到单词本');
        } catch (error) {
          console.error('[Translator] Save failed:', error);
          if (
            error instanceof TranslatorError &&
            error.code === ErrorCode.WORD_ALREADY_EXISTS
          ) {
            toast.info('单词已存在');
          } else {
            toast.error('保存失败');
          }
        }
      },
      target
    );
  } catch (error) {
    if (error instanceof TranslatorError) {
      toast.error(getUserMessage(error.code));
    } else {
      toast.error('翻译失败');
    }
  }
}

// === Paragraph Translation (for future use) ===

const TRANSLATABLE_SELECTORS = [
  'article p',
  'article h1',
  'article h2',
  'article h3',
  'article h4',
  'article h5',
  'article h6',
  'article li',
  'article blockquote',
  'article figcaption',
  '.markdown-body p',
  '.markdown-body h1',
  '.markdown-body h2',
  '.markdown-body h3',
  '.markdown-body h4',
  '.markdown-body li',
  '.markdown-body blockquote',
  'main p',
  'main h1',
  'main h2',
  'main h3',
  '[role="main"] p',
  '[role="main"] h1',
  '[role="main"] h2',
  '[role="main"] h3',
];

const EXCLUDED_SELECTORS = [
  'script',
  'style',
  'noscript',
  'code',
  'pre',
  'input',
  'textarea',
  'button',
  'nav',
  'header',
  'footer',
  'aside',
  '[contenteditable="true"]',
  '[data-translated="true"]',
  '[role="navigation"]',
  '[role="banner"]',
  '[role="tooltip"]',
  '[aria-hidden="true"]',
  '.sr-only',
  '.visually-hidden',
];

function shouldTranslateParagraph(element: HTMLElement): boolean {
  // Check if element matches excluded selectors
  for (const selector of EXCLUDED_SELECTORS) {
    if (element.matches(selector) || element.closest(selector)) {
      return false;
    }
  }

  // Check if element is visible
  const style = window.getComputedStyle(element);
  if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
    return false;
  }

  // Check minimum text length
  const text = element.textContent?.trim() || '';
  if (text.length < 20) return false;

  // Check if already translated
  if (element.dataset.translated === 'true') return false;

  // Check if text is mostly non-Chinese (needs translation to Chinese)
  const chineseChars = (text.match(/[\u4e00-\u9fff]/g) || []).length;
  const chineseRatio = chineseChars / text.length;
  return chineseRatio < 0.3;
}

function getTranslatableParagraphs(): HTMLElement[] {
  const elements: HTMLElement[] = [];

  for (const selector of TRANSLATABLE_SELECTORS) {
    document.querySelectorAll(selector).forEach((el) => {
      const htmlEl = el as HTMLElement;
      if (shouldTranslateParagraph(htmlEl)) {
        elements.push(htmlEl);
      }
    });
  }

  return elements;
}

// Translate all paragraphs on page (can be triggered by user action)
async function translatePage(): Promise<void> {
  const paragraphs = getTranslatableParagraphs();

  for (const paragraph of paragraphs) {
    const text = paragraph.textContent?.trim();
    if (!text) continue;

    try {
      const translation = await translator.translate(text);
      injectTranslation(paragraph, translation);
    } catch {
      // Skip failed translations silently for batch operation
    }
  }
}

// === Message Handler (for background script communication) ===

interface ContentScriptMessage {
  type: 'TRANSLATE_PAGE' | 'TRANSLATE_SELECTION' | 'RESTORE_PAGE';
}

chrome.runtime.onMessage.addListener((message: ContentScriptMessage, _sender, sendResponse) => {
  if (message.type === 'TRANSLATE_PAGE') {
    translatePage()
      .then(() => sendResponse({ success: true }))
      .catch((error: Error) => sendResponse({ success: false, error: error.message }));
    return true; // Keep channel open for async response
  }

  if (message.type === 'TRANSLATE_SELECTION') {
    const selection = window.getSelection();
    const selectedText = selection?.toString().trim();
    if (selectedText) {
      translator
        .translate(selectedText)
        .then((translation) => sendResponse({ success: true, translation }))
        .catch((error: Error) => sendResponse({ success: false, error: error.message }));
    } else {
      sendResponse({ success: false, error: 'No text selected' });
    }
    return true;
  }

  if (message.type === 'RESTORE_PAGE') {
    removeAllTranslations();
    sendResponse({ success: true });
    return true;
  }

  return false;
});

// === Entry Point ===

initialize().catch((error) => {
  console.error('[Translator] Failed to initialize:', error);
});

// Export for testing
export {
  injectTranslation,
  removeTranslation,
  removeAllTranslations,
  shouldTranslateParagraph,
  getTranslatableParagraphs,
};
