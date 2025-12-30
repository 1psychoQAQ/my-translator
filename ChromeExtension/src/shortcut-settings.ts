/**
 * Shortcut Settings Module
 *
 * Manages keyboard shortcuts for translation features.
 * Shortcuts are stored in chrome.storage.sync for persistence.
 */

export interface ShortcutConfig {
  translatePage: string;
  youtubeSubtitle: string;
}

export const DEFAULT_SHORTCUTS: ShortcutConfig = {
  translatePage: 'Meta+KeyZ+KeyX',
  youtubeSubtitle: 'Meta+KeyA+KeyS',
};

const STORAGE_KEY = 'translator-shortcuts';

// Current pressed keys
const pressedKeys = new Set<string>();
let shortcutCallback: ((action: 'translate-page' | 'toggle-youtube') => void) | null = null;
let currentShortcuts: ShortcutConfig = { ...DEFAULT_SHORTCUTS };

/**
 * Load shortcuts from storage
 */
export async function loadShortcuts(): Promise<ShortcutConfig> {
  return new Promise((resolve) => {
    if (typeof chrome !== 'undefined' && chrome.storage) {
      chrome.storage.sync.get(STORAGE_KEY, (result) => {
        const saved = result[STORAGE_KEY] as ShortcutConfig | undefined;
        currentShortcuts = saved || { ...DEFAULT_SHORTCUTS };
        resolve(currentShortcuts);
      });
    } else {
      resolve({ ...DEFAULT_SHORTCUTS });
    }
  });
}

/**
 * Save shortcuts to storage
 */
export async function saveShortcuts(shortcuts: ShortcutConfig): Promise<void> {
  currentShortcuts = shortcuts;
  return new Promise((resolve) => {
    if (typeof chrome !== 'undefined' && chrome.storage) {
      chrome.storage.sync.set({ [STORAGE_KEY]: shortcuts }, resolve);
    } else {
      resolve();
    }
  });
}

/**
 * Get current shortcuts
 */
export function getShortcuts(): ShortcutConfig {
  return currentShortcuts;
}

/**
 * Convert key event to key code string
 */
function getKeyCode(e: KeyboardEvent): string {
  return e.code;
}

/**
 * Check if current pressed keys match a shortcut
 */
function matchesShortcut(shortcut: string): boolean {
  const requiredKeys = shortcut.split('+');
  if (pressedKeys.size !== requiredKeys.length) return false;
  return requiredKeys.every((key) => pressedKeys.has(key));
}

/**
 * Handle keydown event
 */
function handleKeyDown(e: KeyboardEvent): void {
  // Add modifier keys
  if (e.metaKey) pressedKeys.add('Meta');
  if (e.ctrlKey) pressedKeys.add('Control');
  if (e.altKey) pressedKeys.add('Alt');
  if (e.shiftKey) pressedKeys.add('Shift');

  // Add the actual key
  const keyCode = getKeyCode(e);
  if (!['MetaLeft', 'MetaRight', 'ControlLeft', 'ControlRight', 'AltLeft', 'AltRight', 'ShiftLeft', 'ShiftRight'].includes(keyCode)) {
    pressedKeys.add(keyCode);
  }

  // Check shortcuts
  if (shortcutCallback) {
    if (matchesShortcut(currentShortcuts.translatePage)) {
      e.preventDefault();
      shortcutCallback('translate-page');
    } else if (matchesShortcut(currentShortcuts.youtubeSubtitle)) {
      e.preventDefault();
      shortcutCallback('toggle-youtube');
    }
  }
}

/**
 * Handle keyup event
 */
function handleKeyUp(e: KeyboardEvent): void {
  // Remove modifier keys
  if (!e.metaKey) pressedKeys.delete('Meta');
  if (!e.ctrlKey) pressedKeys.delete('Control');
  if (!e.altKey) pressedKeys.delete('Alt');
  if (!e.shiftKey) pressedKeys.delete('Shift');

  // Remove the actual key
  const keyCode = getKeyCode(e);
  pressedKeys.delete(keyCode);
}

/**
 * Clear all pressed keys (e.g., when window loses focus)
 */
function clearPressedKeys(): void {
  pressedKeys.clear();
}

/**
 * Initialize shortcut listeners
 */
export function initShortcutListeners(
  callback: (action: 'translate-page' | 'toggle-youtube') => void
): void {
  shortcutCallback = callback;

  // Load saved shortcuts
  loadShortcuts();

  // Add event listeners
  document.addEventListener('keydown', handleKeyDown);
  document.addEventListener('keyup', handleKeyUp);
  window.addEventListener('blur', clearPressedKeys);
}

/**
 * Remove shortcut listeners
 */
export function removeShortcutListeners(): void {
  shortcutCallback = null;
  document.removeEventListener('keydown', handleKeyDown);
  document.removeEventListener('keyup', handleKeyUp);
  window.removeEventListener('blur', clearPressedKeys);
}

/**
 * Format shortcut for display (e.g., "Meta+KeyZ+KeyX" -> "⌘+Z+X")
 */
export function formatShortcut(shortcut: string): string {
  return shortcut
    .replace(/Meta/g, '⌘')
    .replace(/Control/g, '⌃')
    .replace(/Alt/g, '⌥')
    .replace(/Shift/g, '⇧')
    .replace(/Key([A-Z])/g, '$1')
    .replace(/Digit(\d)/g, '$1')
    .replace(/Arrow(Up|Down|Left|Right)/g, '$1');
}

/**
 * Record a new shortcut from key events
 * Returns a promise that resolves with the recorded shortcut
 */
export function recordShortcut(
  onKeyChange: (current: string) => void
): Promise<string> {
  return new Promise((resolve) => {
    const recordedKeys = new Set<string>();
    let resolved = false;

    const handleRecordKeyDown = (e: KeyboardEvent) => {
      e.preventDefault();
      e.stopPropagation();

      // Add modifier keys
      if (e.metaKey) recordedKeys.add('Meta');
      if (e.ctrlKey) recordedKeys.add('Control');
      if (e.altKey) recordedKeys.add('Alt');
      if (e.shiftKey) recordedKeys.add('Shift');

      // Add the actual key
      const keyCode = getKeyCode(e);
      if (!['MetaLeft', 'MetaRight', 'ControlLeft', 'ControlRight', 'AltLeft', 'AltRight', 'ShiftLeft', 'ShiftRight'].includes(keyCode)) {
        recordedKeys.add(keyCode);
      }

      const shortcut = Array.from(recordedKeys).join('+');
      onKeyChange(shortcut);
    };

    const handleRecordKeyUp = (e: KeyboardEvent) => {
      e.preventDefault();
      e.stopPropagation();

      // Only resolve if we have at least one modifier and one key
      const hasModifier = recordedKeys.has('Meta') || recordedKeys.has('Control') || recordedKeys.has('Alt');
      const hasKey = Array.from(recordedKeys).some(
        (k) => !['Meta', 'Control', 'Alt', 'Shift'].includes(k)
      );

      if (hasModifier && hasKey && !resolved) {
        resolved = true;
        const shortcut = Array.from(recordedKeys).join('+');
        document.removeEventListener('keydown', handleRecordKeyDown, true);
        document.removeEventListener('keyup', handleRecordKeyUp, true);
        resolve(shortcut);
      }
    };

    document.addEventListener('keydown', handleRecordKeyDown, true);
    document.addEventListener('keyup', handleRecordKeyUp, true);
  });
}
