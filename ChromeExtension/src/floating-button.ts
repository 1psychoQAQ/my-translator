/**
 * Floating Translation Button
 *
 * A floating button on the page edge that provides quick access to:
 * - Page translation (immersive mode)
 * - YouTube subtitle translation (on YouTube pages)
 * - Shortcut settings
 */

import {
  loadShortcuts,
  saveShortcuts,
  getShortcuts,
  formatShortcut,
  recordShortcut,
  initShortcutListeners,
  type ShortcutConfig,
} from './shortcut-settings';

const BUTTON_CONTAINER_ID = 'translator-floating-button';

type ButtonClickHandler = (action: 'translate-page' | 'restore-page' | 'toggle-youtube') => void;

interface FloatingButtonOptions {
  onAction: ButtonClickHandler;
  isYouTube: boolean;
}

// Type for elements with stored shadow reference
type ElementWithShadow = HTMLElement & { _shadow?: ShadowRoot };

let isExpanded = false;
let isSettingsOpen = false;
let isPageTranslated = false;
let currentOptions: FloatingButtonOptions | null = null;

export function setPageTranslated(translated: boolean): void {
  isPageTranslated = translated;
  updateMenuItems();
}

function updateMenuItems(): void {
  const container = document.getElementById(BUTTON_CONTAINER_ID) as ElementWithShadow | null;
  if (!container?._shadow) return;

  const restoreItem = container._shadow.querySelector('.menu-item-restore') as HTMLElement;
  const translateItem = container._shadow.querySelector('.menu-item-translate') as HTMLElement;

  if (restoreItem && translateItem) {
    restoreItem.style.display = isPageTranslated ? 'flex' : 'none';
    translateItem.style.display = isPageTranslated ? 'none' : 'flex';
  }
}

function updateShortcutLabels(shadow: ShadowRoot, shortcuts: ShortcutConfig): void {
  const translateShortcut = shadow.querySelector('.shortcut-translate') as HTMLElement;
  const youtubeShortcut = shadow.querySelector('.shortcut-youtube') as HTMLElement;

  if (translateShortcut) {
    translateShortcut.textContent = formatShortcut(shortcuts.translatePage);
  }
  if (youtubeShortcut) {
    youtubeShortcut.textContent = formatShortcut(shortcuts.youtubeSubtitle);
  }
}

export async function createFloatingButton(options: FloatingButtonOptions): Promise<HTMLElement> {
  currentOptions = options;

  // Remove existing button if any
  const existing = document.getElementById(BUTTON_CONTAINER_ID);
  if (existing) {
    existing.remove();
  }

  // Load saved shortcuts
  const shortcuts = await loadShortcuts();

  const container = document.createElement('div') as ElementWithShadow;
  container.id = BUTTON_CONTAINER_ID;

  const shadow = container.attachShadow({ mode: 'closed' });
  container._shadow = shadow;

  const isYouTube = options.isYouTube;

  shadow.innerHTML = `
    <style>
      :host {
        all: initial;
        position: fixed;
        right: 0;
        top: 50%;
        transform: translateY(-50%);
        z-index: 2147483646;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      }

      .floating-wrapper {
        display: flex;
        align-items: center;
        transition: transform 0.3s ease;
      }

      .main-button {
        width: 44px;
        height: 44px;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        border: none;
        border-radius: 22px 0 0 22px;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        box-shadow: -2px 2px 10px rgba(0,0,0,0.2);
        transition: all 0.2s ease;
      }

      .main-button:hover {
        width: 48px;
        background: linear-gradient(135deg, #5a6fd6 0%, #6a4190 100%);
      }

      .main-button svg {
        width: 24px;
        height: 24px;
        fill: white;
        transition: transform 0.3s ease;
      }

      .floating-wrapper.expanded .main-button svg {
        transform: rotate(180deg);
      }

      .menu {
        display: none;
        flex-direction: column;
        background: white;
        border-radius: 8px 0 0 8px;
        box-shadow: -2px 2px 15px rgba(0,0,0,0.15);
        overflow: hidden;
        margin-right: -1px;
        min-width: 180px;
      }

      .floating-wrapper.expanded .menu {
        display: flex;
      }

      .menu-item {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 8px;
        padding: 12px 16px;
        border: none;
        background: white;
        cursor: pointer;
        font-size: 14px;
        color: #333;
        white-space: nowrap;
        transition: background 0.2s;
      }

      .menu-item:hover {
        background: #f5f5f5;
      }

      .menu-item:not(:last-child) {
        border-bottom: 1px solid #eee;
      }

      .menu-item-left {
        display: flex;
        align-items: center;
        gap: 8px;
      }

      .menu-item svg {
        width: 18px;
        height: 18px;
        fill: #666;
      }

      .menu-item-translate svg {
        fill: #667eea;
      }

      .menu-item-restore svg {
        fill: #e67e22;
      }

      .menu-item-youtube svg {
        fill: #ff0000;
      }

      .menu-item-settings svg {
        fill: #888;
      }

      .menu-item-restore {
        display: none;
      }

      .shortcut-badge {
        font-size: 11px;
        color: #999;
        background: #f0f0f0;
        padding: 2px 6px;
        border-radius: 4px;
      }

      /* Settings Panel */
      .settings-panel {
        display: none;
        flex-direction: column;
        background: white;
        border-radius: 8px 0 0 8px;
        box-shadow: -2px 2px 15px rgba(0,0,0,0.15);
        margin-right: -1px;
        min-width: 280px;
        padding: 16px;
      }

      .settings-panel.open {
        display: flex;
      }

      .settings-title {
        font-size: 14px;
        font-weight: 600;
        color: #333;
        margin-bottom: 16px;
        display: flex;
        align-items: center;
        justify-content: space-between;
      }

      .settings-close {
        background: none;
        border: none;
        cursor: pointer;
        padding: 4px;
        color: #666;
        font-size: 18px;
      }

      .settings-close:hover {
        color: #333;
      }

      .shortcut-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 12px;
        padding-bottom: 12px;
        border-bottom: 1px solid #eee;
      }

      .shortcut-row:last-child {
        border-bottom: none;
        margin-bottom: 0;
        padding-bottom: 0;
      }

      .shortcut-label {
        font-size: 13px;
        color: #333;
      }

      .shortcut-input {
        display: flex;
        align-items: center;
        gap: 8px;
      }

      .shortcut-key {
        font-size: 12px;
        color: #666;
        background: #f5f5f5;
        padding: 6px 10px;
        border-radius: 4px;
        min-width: 80px;
        text-align: center;
        border: 1px solid #ddd;
      }

      .shortcut-key.recording {
        background: #fff3e0;
        border-color: #ff9800;
        color: #e65100;
      }

      .edit-btn {
        background: #667eea;
        color: white;
        border: none;
        padding: 6px 12px;
        border-radius: 4px;
        font-size: 12px;
        cursor: pointer;
        transition: background 0.2s;
      }

      .edit-btn:hover {
        background: #5a6fd6;
      }

      .edit-btn.recording {
        background: #ff9800;
      }
    </style>

    <div class="floating-wrapper">
      <div class="menu">
        <button class="menu-item menu-item-translate" data-action="translate-page">
          <div class="menu-item-left">
            <svg viewBox="0 0 24 24"><path d="M12.87 15.07l-2.54-2.51.03-.03A17.52 17.52 0 0014.07 6H17V4h-7V2H8v2H1v2h11.17C11.5 7.92 10.44 9.75 9 11.35 8.07 10.32 7.3 9.19 6.69 8h-2c.73 1.63 1.73 3.17 2.98 4.56l-5.09 5.02L4 19l5-5 3.11 3.11.76-2.04zM18.5 10h-2L12 22h2l1.12-3h4.75L21 22h2l-4.5-12zm-2.62 7l1.62-4.33L19.12 17h-3.24z"/></svg>
            <span>翻译页面</span>
          </div>
          <span class="shortcut-badge shortcut-translate">${formatShortcut(shortcuts.translatePage)}</span>
        </button>
        <button class="menu-item menu-item-restore" data-action="restore-page">
          <div class="menu-item-left">
            <svg viewBox="0 0 24 24"><path d="M12.5 8c-2.65 0-5.05.99-6.9 2.6L2 7v9h9l-3.62-3.62c1.39-1.16 3.16-1.88 5.12-1.88 3.54 0 6.55 2.31 7.6 5.5l2.37-.78C21.08 11.03 17.15 8 12.5 8z"/></svg>
            <span>恢复原文</span>
          </div>
        </button>
        ${isYouTube ? `
        <button class="menu-item menu-item-youtube" data-action="toggle-youtube">
          <div class="menu-item-left">
            <svg viewBox="0 0 24 24"><path d="M10 15l5.19-3L10 9v6m11.56-7.83c.13.47.22 1.1.28 1.9.07.8.1 1.49.1 2.09L22 12c0 2.19-.16 3.8-.44 4.83-.25.9-.83 1.48-1.73 1.73-.47.13-1.33.22-2.65.28-1.3.07-2.49.1-3.59.1L12 19c-4.19 0-6.8-.16-7.83-.44-.9-.25-1.48-.83-1.73-1.73-.13-.47-.22-1.1-.28-1.9-.07-.8-.1-1.49-.1-2.09L2 12c0-2.19.16-3.8.44-4.83.25-.9.83-1.48 1.73-1.73.47-.13 1.33-.22 2.65-.28 1.3-.07 2.49-.1 3.59-.1L12 5c4.19 0 6.8.16 7.83.44.9.25 1.48.83 1.73 1.73z"/></svg>
            <span>双语字幕</span>
          </div>
          <span class="shortcut-badge shortcut-youtube">${formatShortcut(shortcuts.youtubeSubtitle)}</span>
        </button>
        ` : ''}
        <button class="menu-item menu-item-settings" data-action="settings">
          <div class="menu-item-left">
            <svg viewBox="0 0 24 24"><path d="M19.14 12.94c.04-.31.06-.63.06-.94 0-.31-.02-.63-.06-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"/></svg>
            <span>快捷键设置</span>
          </div>
        </button>
      </div>

      <div class="settings-panel">
        <div class="settings-title">
          <span>快捷键设置</span>
          <button class="settings-close">&times;</button>
        </div>
        <div class="shortcut-row">
          <span class="shortcut-label">翻译页面</span>
          <div class="shortcut-input">
            <span class="shortcut-key" data-shortcut="translatePage">${formatShortcut(shortcuts.translatePage)}</span>
            <button class="edit-btn" data-edit="translatePage">编辑</button>
          </div>
        </div>
        <div class="shortcut-row">
          <span class="shortcut-label">双语字幕</span>
          <div class="shortcut-input">
            <span class="shortcut-key" data-shortcut="youtubeSubtitle">${formatShortcut(shortcuts.youtubeSubtitle)}</span>
            <button class="edit-btn" data-edit="youtubeSubtitle">编辑</button>
          </div>
        </div>
      </div>

      <button class="main-button" title="翻译">
        <svg viewBox="0 0 24 24"><path d="M12.87 15.07l-2.54-2.51.03-.03A17.52 17.52 0 0014.07 6H17V4h-7V2H8v2H1v2h11.17C11.5 7.92 10.44 9.75 9 11.35 8.07 10.32 7.3 9.19 6.69 8h-2c.73 1.63 1.73 3.17 2.98 4.56l-5.09 5.02L4 19l5-5 3.11 3.11.76-2.04zM18.5 10h-2L12 22h2l1.12-3h4.75L21 22h2l-4.5-12zm-2.62 7l1.62-4.33L19.12 17h-3.24z"/></svg>
      </button>
    </div>
  `;

  // Event handlers
  const wrapper = shadow.querySelector('.floating-wrapper') as HTMLElement;
  const mainButton = shadow.querySelector('.main-button') as HTMLButtonElement;
  const menu = shadow.querySelector('.menu') as HTMLElement;
  const settingsPanel = shadow.querySelector('.settings-panel') as HTMLElement;
  const menuItems = shadow.querySelectorAll('.menu-item');
  const settingsClose = shadow.querySelector('.settings-close') as HTMLButtonElement;
  const editButtons = shadow.querySelectorAll('.edit-btn');

  // Main button click
  mainButton.addEventListener('click', (e) => {
    e.stopPropagation();
    if (isSettingsOpen) {
      isSettingsOpen = false;
      settingsPanel.classList.remove('open');
    }
    isExpanded = !isExpanded;
    wrapper.classList.toggle('expanded', isExpanded);
    if (!isExpanded) {
      menu.style.display = 'none';
    }
  });

  // Menu item clicks
  menuItems.forEach((item) => {
    item.addEventListener('click', (e) => {
      e.stopPropagation();
      const action = (item as HTMLElement).dataset.action;

      if (action === 'settings') {
        // Open settings panel
        isSettingsOpen = true;
        menu.style.display = 'none';
        settingsPanel.classList.add('open');
        return;
      }

      if (action) {
        options.onAction(action as 'translate-page' | 'restore-page' | 'toggle-youtube');
      }
      // Close menu after action
      isExpanded = false;
      wrapper.classList.remove('expanded');
    });
  });

  // Settings close button
  settingsClose.addEventListener('click', (e) => {
    e.stopPropagation();
    isSettingsOpen = false;
    settingsPanel.classList.remove('open');
    isExpanded = false;
    wrapper.classList.remove('expanded');
  });

  // Edit shortcut buttons
  editButtons.forEach((btn) => {
    btn.addEventListener('click', async (e) => {
      e.stopPropagation();
      const shortcutType = (btn as HTMLElement).dataset.edit as keyof ShortcutConfig;
      const keyDisplay = shadow.querySelector(`[data-shortcut="${shortcutType}"]`) as HTMLElement;

      if (!keyDisplay) return;

      // Set recording state
      keyDisplay.classList.add('recording');
      (btn as HTMLElement).classList.add('recording');
      (btn as HTMLElement).textContent = '按下快捷键...';
      keyDisplay.textContent = '等待输入...';

      try {
        const newShortcut = await recordShortcut((current) => {
          keyDisplay.textContent = formatShortcut(current);
        });

        // Save the new shortcut
        const currentShortcuts = getShortcuts();
        currentShortcuts[shortcutType] = newShortcut;
        await saveShortcuts(currentShortcuts);

        // Update display
        keyDisplay.textContent = formatShortcut(newShortcut);
        updateShortcutLabels(shadow, currentShortcuts);
      } finally {
        // Reset recording state
        keyDisplay.classList.remove('recording');
        (btn as HTMLElement).classList.remove('recording');
        (btn as HTMLElement).textContent = '编辑';
      }
    });
  });

  // Close menu when clicking outside
  document.addEventListener('click', () => {
    if (isExpanded || isSettingsOpen) {
      isExpanded = false;
      isSettingsOpen = false;
      wrapper.classList.remove('expanded');
      settingsPanel.classList.remove('open');
    }
  });

  // Initialize shortcut listeners
  initShortcutListeners((action) => {
    if (action === 'translate-page') {
      // Toggle translate/restore
      if (isPageTranslated) {
        options.onAction('restore-page');
      } else {
        options.onAction('translate-page');
      }
    } else if (action === 'toggle-youtube') {
      options.onAction('toggle-youtube');
    }
  });

  document.body.appendChild(container);
  return container;
}

export function removeFloatingButton(): void {
  const container = document.getElementById(BUTTON_CONTAINER_ID);
  if (container) {
    container.remove();
  }
}
