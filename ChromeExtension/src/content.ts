import { createMessengerWithFallback } from './native-messenger';
import { createWordBookService, createWordEntry } from './wordbook';
import { createToast } from './toast';
import { TranslatorError, ErrorCode, getUserMessage } from './errors';
import type { WordBookService, ToastNotification, NativeMessenger } from './types';
import { showCoffeePrompt } from './support';

// === Constants ===

const WORD_POPUP_ID = 'translator-word-popup';

// Sentence boundary patterns
const SENTENCE_END_PATTERN = /[.!?。！？；;]/;

// === Global State ===

let wordBook: WordBookService;
let toast: ToastNotification;
let messenger: NativeMessenger;
let isInitialized = false;

// === Text-to-Speech (通过 Native Messaging 调用 macOS) ===

/**
 * 朗读文本（通过 macOS 系统发音）
 * @param text 要朗读的文本
 */
function speakText(text: string): void {
  if (!messenger) return;

  // 发送到 macOS 进行朗读（不等待响应）
  messenger.send({
    action: 'speak',
    payload: { text, language: 'en-US' },
  }).catch(() => {
    // 静默失败
  });
}

// === Translation via Background Script ===

interface TranslateResponse {
  success: boolean;
  translation?: string;
  error?: string;
  coffeePrompt?: {
    shouldShow: boolean;
    translationCount: number;
    milestone?: number;
  };
}

async function translateText(text: string, context?: string): Promise<TranslateResponse> {
  return new Promise((resolve) => {
    chrome.runtime.sendMessage(
      { type: 'TRANSLATE', text, context },
      (response: TranslateResponse) => {
        if (chrome.runtime.lastError) {
          resolve({ success: false, error: chrome.runtime.lastError.message });
        } else {
          resolve(response);
        }
      }
    );
  });
}

function handleCoffeePrompt(translationCount: number): void {
  showCoffeePrompt({
    translationCount,
    onSupport: () => {
      chrome.runtime.sendMessage({ type: 'MARK_AS_SUPPORTER' });
    },
    onDismiss: () => {
      chrome.runtime.sendMessage({ type: 'DISMISS_PROMPT' });
    },
    onAlreadySupported: () => {
      chrome.runtime.sendMessage({ type: 'MARK_AS_SUPPORTER' });
    },
  });
}

// === Initialization ===

async function initialize(): Promise<void> {
  if (isInitialized) return;

  messenger = await createMessengerWithFallback();
  wordBook = createWordBookService(messenger);
  toast = createToast();

  isInitialized = true;

  // Set up event listeners
  setupSelectionHandler();
}

// === Sentence Extraction ===

/**
 * Extract the sentence containing the selection from the text content
 */
function extractSentence(container: Node, range: Range): string {
  // Get the text content of the container
  const textNode = container.nodeType === Node.TEXT_NODE ? container : container;
  const fullText = textNode.textContent || '';

  if (!fullText) return '';

  // Get the position of selection within the text
  const selectedText = range.toString();

  // Find the text node and offset
  let startOffset = 0;
  if (container.nodeType === Node.TEXT_NODE) {
    startOffset = range.startOffset;
  } else {
    // For element nodes, we need to find the actual text position
    const treeWalker = document.createTreeWalker(
      container,
      NodeFilter.SHOW_TEXT,
      null
    );
    let currentOffset = 0;
    let node: Node | null = treeWalker.nextNode();
    while (node) {
      if (node === range.startContainer) {
        startOffset = currentOffset + range.startOffset;
        break;
      }
      currentOffset += (node.textContent || '').length;
      node = treeWalker.nextNode();
    }
  }

  // Find sentence boundaries
  // Look backwards for sentence start
  let sentenceStart = 0;
  for (let i = startOffset - 1; i >= 0; i--) {
    if (SENTENCE_END_PATTERN.test(fullText[i])) {
      sentenceStart = i + 1;
      // Skip whitespace after punctuation
      while (sentenceStart < fullText.length && /\s/.test(fullText[sentenceStart])) {
        sentenceStart++;
      }
      break;
    }
  }

  // Look forwards for sentence end
  let sentenceEnd = fullText.length;
  for (let i = startOffset + selectedText.length; i < fullText.length; i++) {
    if (SENTENCE_END_PATTERN.test(fullText[i])) {
      sentenceEnd = i + 1;
      break;
    }
  }

  return fullText.slice(sentenceStart, sentenceEnd).trim();
}

/**
 * Get the parent element that contains meaningful text
 */
function getTextContainer(node: Node): Element | null {
  let current: Node | null = node;

  while (current) {
    if (current.nodeType === Node.ELEMENT_NODE) {
      const element = current as Element;
      // Check if this is a block-level text container
      const tagName = element.tagName.toLowerCase();
      if (['p', 'div', 'span', 'li', 'td', 'th', 'blockquote', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'article', 'section'].includes(tagName)) {
        return element;
      }
    }
    current = current.parentNode;
  }

  return null;
}

// === Word Popup ===

function getElementBackground(element: Element): { bg: string; textColor: string; isDark: boolean } {
  let el: Element | null = element;
  while (el) {
    const style = window.getComputedStyle(el);
    const bg = style.backgroundColor;
    if (bg && bg !== 'transparent' && bg !== 'rgba(0, 0, 0, 0)') {
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

function escapeHtml(text: string): string {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
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

  const { bg, textColor, isDark } = targetElement
    ? getElementBackground(targetElement)
    : { bg: '#ffffff', textColor: '#222', isDark: false };

  const popup = document.createElement('div');
  popup.id = WORD_POPUP_ID;
  popup.style.cssText = 'position: fixed; z-index: 2147483647; pointer-events: none;';

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
      .word {
        font-size: 14px;
        font-weight: 600;
        color: ${textColor};
        margin-bottom: 4px;
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
      .speak-btn {
        background: transparent;
        color: ${textColor};
        padding: 4px 8px;
        min-width: auto;
        opacity: 0.7;
      }
      .speak-btn:hover {
        opacity: 1;
        background: ${isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.05)'};
      }
      .word-row {
        display: flex;
        align-items: center;
        gap: 4px;
        margin-bottom: 4px;
      }
      .word-text {
        font-size: 14px;
        font-weight: 600;
        color: ${textColor};
      }
    </style>
    <div class="popup">
      <div class="word-row">
        <span class="word-text">${escapeHtml(originalText)}</span>
        <button class="speak-btn" title="朗读">🔊</button>
      </div>
      <div class="translation">${escapeHtml(translation)}</div>
      <div class="actions">
        <button class="save-btn">收藏</button>
        <button class="close-btn">关闭</button>
      </div>
    </div>
  `;

  document.body.appendChild(popup);

  const saveBtn = shadow.querySelector('.save-btn');
  const closeBtn = shadow.querySelector('.close-btn');
  const speakBtn = shadow.querySelector('.speak-btn');

  saveBtn?.addEventListener('click', () => {
    onSave();
    removeWordPopup();
  });

  closeBtn?.addEventListener('click', removeWordPopup);

  speakBtn?.addEventListener('click', () => {
    speakText(originalText);
  });

  const popupInner = shadow.querySelector('.popup') as HTMLElement;

  setTimeout(() => {
    document.addEventListener('click', handleOutsideClick);
  }, 100);

  function handleOutsideClick(e: MouseEvent): void {
    if (!popupInner) {
      removeWordPopup();
      document.removeEventListener('click', handleOutsideClick);
      return;
    }

    const rect = popupInner.getBoundingClientRect();
    const isInside =
      e.clientX >= rect.left &&
      e.clientX <= rect.right &&
      e.clientY >= rect.top &&
      e.clientY <= rect.bottom;

    if (!isInside) {
      removeWordPopup();
      document.removeEventListener('click', handleOutsideClick);
    }
  }

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

// === Selection Handler ===

function setupSelectionHandler(): void {
  document.addEventListener('mouseup', handleMouseUp);
}

async function handleMouseUp(event: MouseEvent): Promise<void> {
  // Small delay to ensure selection is complete
  await new Promise(resolve => setTimeout(resolve, 10));

  const selection = window.getSelection();
  if (!selection || selection.isCollapsed) return;

  const selectedText = selection.toString().trim();

  if (!selectedText || selectedText.length === 0) return;

  // Limit to reasonable word/phrase length
  if (selectedText.length > 100) return;
  if (selectedText.split(/\s+/).length > 10) return;

  // Don't handle if clicking on our own elements
  const target = event.target as HTMLElement;
  if (target.closest(`#${WORD_POPUP_ID}`)) {
    return;
  }

  // Get the range and extract sentence
  const range = selection.getRangeAt(0);
  const container = range.startContainer;

  // Find the text container element
  const textContainer = getTextContainer(container);

  // Extract the full sentence
  let sentence = '';
  if (textContainer) {
    sentence = extractSentence(textContainer, range);
  }

  try {
    // 传入句子作为上下文，实现语境翻译
    const response = await translateText(selectedText, sentence);

    if (!response.success || !response.translation) {
      toast.error(response.error || '翻译失败');
      return;
    }

    const translation = response.translation;

    // Show coffee prompt if triggered
    if (response.coffeePrompt?.shouldShow) {
      // Delay slightly so it doesn't interfere with popup
      setTimeout(() => {
        handleCoffeePrompt(response.coffeePrompt!.translationCount);
      }, 500);
    }

    showWordPopup(
      event.clientX,
      event.clientY,
      selectedText,
      translation,
      async () => {
        try {
          // 收藏时保存句子和网页链接
          const word = createWordEntry(
            selectedText,
            translation,
            window.location.href,
            sentence
          );
          await wordBook.save(word);
          toast.success('已收藏到单词本');
        } catch (error) {
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

// === Entry Point ===

initialize().catch(() => {
  // Silent fail - user will see error when trying to use features
});

// Export for testing
export {
  extractSentence,
  getTextContainer,
};
