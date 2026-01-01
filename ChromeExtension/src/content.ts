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

function escapeHtml(text: string): string {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function copyToClipboard(text: string): void {
  navigator.clipboard.writeText(text).catch(() => {
    // Fallback for older browsers
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand('copy');
    document.body.removeChild(textarea);
  });
}

function showWordPopup(
  x: number,
  y: number,
  originalText: string,
  translation: string,
  onSave: () => void,
  _targetElement?: Element
): void {
  removeWordPopup();

  const popup = document.createElement('div');
  popup.id = WORD_POPUP_ID;
  popup.style.cssText = 'position: fixed; z-index: 2147483647; pointer-events: none;';

  const viewportWidth = window.innerWidth;
  const viewportHeight = window.innerHeight;
  const popupWidth = 280;
  const popupHeight = 140;

  let posX = x + 10;
  let posY = y + 10;

  if (posX + popupWidth > viewportWidth) {
    posX = x - popupWidth - 10;
  }
  if (posY + popupHeight > viewportHeight) {
    posY = y - popupHeight - 10;
  }

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
        background: rgba(40, 40, 40, 0.85);
        backdrop-filter: blur(20px);
        -webkit-backdrop-filter: blur(20px);
        border: 1px solid rgba(255, 255, 255, 0.15);
        border-radius: 10px;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
        padding: 12px 14px;
        max-width: 280px;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
        pointer-events: auto;
        animation: popupFadeIn 0.15s ease-out;
        color: white;
      }
      @keyframes popupFadeIn {
        from { opacity: 0; transform: translateY(-4px); }
        to { opacity: 1; transform: translateY(0); }
      }
      .section {
        margin-bottom: 8px;
      }
      .section-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 4px;
      }
      .section-label {
        font-size: 10px;
        font-weight: 500;
        color: rgba(255, 255, 255, 0.5);
      }
      .section-text {
        font-size: 13px;
        line-height: 1.4;
        word-break: break-word;
        color: white;
      }
      .divider {
        height: 1px;
        background: rgba(255, 255, 255, 0.15);
        margin: 8px 0;
      }
      .actions {
        display: flex;
        gap: 8px;
        margin-top: 10px;
      }
      button {
        padding: 6px 12px;
        border: none;
        border-radius: 6px;
        cursor: pointer;
        font-size: 11px;
        font-weight: 500;
        transition: all 0.15s;
      }
      .save-btn {
        background: #007aff;
        color: white;
      }
      .save-btn:hover {
        background: #0056b3;
      }
      .close-btn {
        background: rgba(255, 255, 255, 0.15);
        color: rgba(255, 255, 255, 0.8);
      }
      .close-btn:hover {
        background: rgba(255, 255, 255, 0.25);
      }
      .icon-btn {
        background: transparent;
        color: rgba(255, 255, 255, 0.5);
        padding: 4px 6px;
        min-width: auto;
        font-size: 11px;
        display: inline-flex;
        align-items: center;
        transition: all 0.15s ease;
      }
      .icon-btn:hover {
        color: rgba(255, 255, 255, 0.9);
        background: rgba(255, 255, 255, 0.1);
      }
      .icon-btn.copied {
        color: rgba(255, 255, 255, 0.9);
      }
      .word-row {
        display: flex;
        align-items: center;
        gap: 4px;
      }
    </style>
    <div class="popup">
      <div class="section">
        <div class="section-header">
          <span class="section-label">原文</span>
          <div class="word-row">
            <button class="icon-btn copy-original-btn" title="复制">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>
            </button>
            <button class="icon-btn speak-btn" title="朗读">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M15.54 8.46a5 5 0 0 1 0 7.07"></path></svg>
            </button>
          </div>
        </div>
        <div class="section-text original-text">${escapeHtml(originalText)}</div>
      </div>
      <div class="divider"></div>
      <div class="section">
        <div class="section-header">
          <span class="section-label">译文</span>
          <button class="icon-btn copy-translation-btn" title="复制">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>
          </button>
        </div>
        <div class="section-text">${escapeHtml(translation)}</div>
      </div>
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
  const copyOriginalBtn = shadow.querySelector('.copy-original-btn');
  const copyTranslationBtn = shadow.querySelector('.copy-translation-btn');

  saveBtn?.addEventListener('click', () => {
    onSave();
    removeWordPopup();
  });

  closeBtn?.addEventListener('click', removeWordPopup);

  speakBtn?.addEventListener('click', () => {
    speakText(originalText);
  });

  copyOriginalBtn?.addEventListener('click', () => {
    copyToClipboard(originalText);
    copyOriginalBtn.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>';
    copyOriginalBtn.classList.add('copied');
    setTimeout(() => {
      copyOriginalBtn.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>';
      copyOriginalBtn.classList.remove('copied');
    }, 1200);
  });

  copyTranslationBtn?.addEventListener('click', () => {
    copyToClipboard(translation);
    copyTranslationBtn.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>';
    copyTranslationBtn.classList.add('copied');
    setTimeout(() => {
      copyTranslationBtn.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>';
      copyTranslationBtn.classList.remove('copied');
    }, 1200);
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
