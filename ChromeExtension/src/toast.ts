import type { ToastNotification } from './types';

const TOAST_CONTAINER_ID = 'translator-toast-container';
const TOAST_DURATION = 3000; // 3 seconds

type ToastType = 'success' | 'error' | 'info';

interface ToastConfig {
  backgroundColor: string;
  borderColor: string;
  icon: string;
}

const TOAST_CONFIGS: Record<ToastType, ToastConfig> = {
  success: {
    backgroundColor: '#f0fdf4',
    borderColor: '#22c55e',
    icon: '\u2713', // checkmark
  },
  error: {
    backgroundColor: '#fef2f2',
    borderColor: '#ef4444',
    icon: '\u2717', // x mark
  },
  info: {
    backgroundColor: '#eff6ff',
    borderColor: '#3b82f6',
    icon: '\u2139', // info
  },
};

function getOrCreateContainer(): HTMLElement {
  let container = document.getElementById(TOAST_CONTAINER_ID);

  if (!container) {
    container = document.createElement('div');
    container.id = TOAST_CONTAINER_ID;

    const shadow = container.attachShadow({ mode: 'closed' });
    shadow.innerHTML = `
      <style>
        :host {
          all: initial;
        }
        .container {
          position: fixed;
          top: 20px;
          right: 20px;
          z-index: 2147483647;
          display: flex;
          flex-direction: column;
          gap: 8px;
          pointer-events: none;
        }
        .toast {
          padding: 12px 16px;
          border-radius: 8px;
          border-left: 4px solid;
          box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          font-size: 14px;
          display: flex;
          align-items: center;
          gap: 8px;
          animation: slideIn 0.3s ease-out;
          pointer-events: auto;
        }
        .toast.hiding {
          animation: slideOut 0.3s ease-in forwards;
        }
        .icon {
          font-size: 16px;
          font-weight: bold;
        }
        .message {
          color: #333;
        }
        @keyframes slideIn {
          from {
            opacity: 0;
            transform: translateX(100%);
          }
          to {
            opacity: 1;
            transform: translateX(0);
          }
        }
        @keyframes slideOut {
          from {
            opacity: 1;
            transform: translateX(0);
          }
          to {
            opacity: 0;
            transform: translateX(100%);
          }
        }
      </style>
      <div class="container"></div>
    `;

    document.body.appendChild(container);
  }

  return container;
}

function showToast(type: ToastType, message: string): void {
  const container = getOrCreateContainer();
  const shadow = container.shadowRoot;
  if (!shadow) return;

  const toastContainer = shadow.querySelector('.container');
  if (!toastContainer) return;

  const config = TOAST_CONFIGS[type];

  const toast = document.createElement('div');
  toast.className = 'toast';
  toast.style.backgroundColor = config.backgroundColor;
  toast.style.borderColor = config.borderColor;

  toast.innerHTML = `
    <span class="icon" style="color: ${config.borderColor}">${config.icon}</span>
    <span class="message">${escapeHtml(message)}</span>
  `;

  toastContainer.appendChild(toast);

  // Auto remove after duration
  setTimeout(() => {
    toast.classList.add('hiding');
    setTimeout(() => {
      toast.remove();
      // Remove container if empty
      if (toastContainer.children.length === 0) {
        container.remove();
      }
    }, 300);
  }, TOAST_DURATION);
}

function escapeHtml(text: string): string {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

export function createToast(): ToastNotification {
  return {
    success(message: string): void {
      showToast('success', message);
    },
    error(message: string): void {
      showToast('error', message);
    },
    info(message: string): void {
      showToast('info', message);
    },
  };
}
