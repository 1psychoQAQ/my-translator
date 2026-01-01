/**
 * Coffee Prompt UI
 * Non-intrusive "buy me a coffee" prompt
 */

import { PAYMENT_LINKS } from './types';

const PROMPT_ID = 'translator-coffee-prompt';

const STYLES = `
  #${PROMPT_ID} {
    position: fixed;
    bottom: 24px;
    right: 24px;
    width: 320px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-radius: 16px;
    padding: 20px;
    box-shadow: 0 10px 40px rgba(102, 126, 234, 0.4);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    z-index: 2147483647;
    animation: slideIn 0.3s ease-out;
    color: white;
  }

  @keyframes slideIn {
    from {
      opacity: 0;
      transform: translateY(20px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  #${PROMPT_ID} .coffee-header {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 12px;
  }

  #${PROMPT_ID} .coffee-icon {
    font-size: 32px;
  }

  #${PROMPT_ID} .coffee-title {
    font-size: 16px;
    font-weight: 600;
    margin: 0;
  }

  #${PROMPT_ID} .coffee-stats {
    font-size: 13px;
    opacity: 0.9;
    margin: 0;
  }

  #${PROMPT_ID} .coffee-message {
    font-size: 14px;
    line-height: 1.5;
    margin: 12px 0;
    opacity: 0.95;
  }

  #${PROMPT_ID} .coffee-buttons {
    display: flex;
    gap: 8px;
    margin-top: 16px;
  }

  #${PROMPT_ID} .coffee-btn {
    flex: 1;
    padding: 10px 16px;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
  }

  #${PROMPT_ID} .coffee-btn-primary {
    background: white;
    color: #667eea;
  }

  #${PROMPT_ID} .coffee-btn-primary:hover {
    transform: scale(1.02);
    box-shadow: 0 4px 12px rgba(0,0,0,0.2);
  }

  #${PROMPT_ID} .coffee-btn-secondary {
    background: rgba(255,255,255,0.2);
    color: white;
  }

  #${PROMPT_ID} .coffee-btn-secondary:hover {
    background: rgba(255,255,255,0.3);
  }

  #${PROMPT_ID} .coffee-btn-text {
    background: transparent;
    color: rgba(255,255,255,0.7);
    padding: 8px;
    font-size: 12px;
  }

  #${PROMPT_ID} .coffee-btn-text:hover {
    color: white;
  }

  #${PROMPT_ID} .coffee-close {
    position: absolute;
    top: 12px;
    right: 12px;
    background: rgba(255,255,255,0.2);
    border: none;
    color: white;
    width: 24px;
    height: 24px;
    border-radius: 50%;
    cursor: pointer;
    font-size: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  #${PROMPT_ID} .coffee-close:hover {
    background: rgba(255,255,255,0.3);
  }

  #${PROMPT_ID} .coffee-footer {
    display: flex;
    justify-content: center;
    margin-top: 12px;
  }

  #${PROMPT_ID}.hiding {
    animation: slideOut 0.2s ease-in forwards;
  }

  @keyframes slideOut {
    to {
      opacity: 0;
      transform: translateY(20px);
    }
  }
`;

export interface CoffeePromptOptions {
  translationCount: number;
  onSupport: () => void;
  onDismiss: () => void;
  onAlreadySupported: () => void;
}

export function showCoffeePrompt(options: CoffeePromptOptions): void {
  // Don't show if already exists
  if (document.getElementById(PROMPT_ID)) {
    return;
  }

  const { translationCount, onSupport, onDismiss, onAlreadySupported } = options;

  // Inject styles
  const styleId = `${PROMPT_ID}-styles`;
  if (!document.getElementById(styleId)) {
    const style = document.createElement('style');
    style.id = styleId;
    style.textContent = STYLES;
    document.head.appendChild(style);
  }

  // Create prompt element
  const prompt = document.createElement('div');
  prompt.id = PROMPT_ID;
  prompt.innerHTML = `
    <button class="coffee-close" title="关闭">×</button>
    <div class="coffee-header">
      <span class="coffee-icon">☕</span>
      <div>
        <p class="coffee-title">感谢你的使用！</p>
        <p class="coffee-stats">已帮你翻译 ${translationCount.toLocaleString()} 次</p>
      </div>
    </div>
    <p class="coffee-message">
      这个工具完全免费开源。如果它帮到了你，请考虑请作者喝杯咖啡，支持持续开发 ❤️
    </p>
    <div class="coffee-buttons">
      <button class="coffee-btn coffee-btn-primary" data-action="support">
        ☕ 请喝咖啡 ¥9.9
      </button>
      <button class="coffee-btn coffee-btn-secondary" data-action="dismiss">
        下次再说
      </button>
    </div>
    <div class="coffee-footer">
      <button class="coffee-btn coffee-btn-text" data-action="already">
        我已经支持过了
      </button>
    </div>
  `;

  // Event handlers
  const hidePrompt = (): void => {
    prompt.classList.add('hiding');
    setTimeout(() => prompt.remove(), 200);
  };

  prompt.querySelector('.coffee-close')?.addEventListener('click', () => {
    hidePrompt();
    onDismiss();
  });

  prompt.querySelector('[data-action="support"]')?.addEventListener('click', () => {
    // Open payment link
    const paymentUrl = PAYMENT_LINKS.afdian || PAYMENT_LINKS.buymeacoffee;
    if (paymentUrl && paymentUrl !== 'https://afdian.com/a/your-username') {
      window.open(paymentUrl, '_blank');
    } else {
      // Fallback: show alert with instructions
      alert('感谢支持！请通过 GitHub 页面的赞助链接支持作者。');
    }
    hidePrompt();
    onSupport();
  });

  prompt.querySelector('[data-action="dismiss"]')?.addEventListener('click', () => {
    hidePrompt();
    onDismiss();
  });

  prompt.querySelector('[data-action="already"]')?.addEventListener('click', () => {
    hidePrompt();
    onAlreadySupported();
  });

  // Add to page
  document.body.appendChild(prompt);

  // Auto-hide after 30 seconds if no interaction
  setTimeout(() => {
    if (document.getElementById(PROMPT_ID)) {
      hidePrompt();
      onDismiss();
    }
  }, 30000);
}

export function hideCoffeePrompt(): void {
  const prompt = document.getElementById(PROMPT_ID);
  if (prompt) {
    prompt.classList.add('hiding');
    setTimeout(() => prompt.remove(), 200);
  }
}
