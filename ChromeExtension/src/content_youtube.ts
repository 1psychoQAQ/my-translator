/**
 * YouTube Subtitle Translator - Immersive bilingual subtitle display
 *
 * This content script:
 * 1. Detects YouTube video player and subtitle tracks
 * 2. Intercepts subtitle cues via TextTrack API
 * 3. Translates and displays bilingual subtitles
 */

import { createTranslationCache } from './cache';
import { createMessengerWithFallback } from './native-messenger';
import { createTranslator } from './translator';
import { createWordBookService, createWordEntry } from './wordbook';
import { createToast } from './toast';
import { TranslatorError, ErrorCode } from './errors';
import type { Translator, WordBookService, ToastNotification } from './types';

// === Constants ===

const SUBTITLE_CONTAINER_ID = 'translator-youtube-subtitles';
const SUBTITLE_TOGGLE_ID = 'translator-youtube-toggle';

// === Global State ===

let translator: Translator;
let wordBook: WordBookService;
let toast: ToastNotification;
let isInitialized = false;
let isEnabled = true;
let currentVideo: HTMLVideoElement | null = null;
let subtitleObserver: MutationObserver | null = null;
// Track state is managed by the TextTrack event listeners

// Cache for translated subtitles to avoid re-translating
const translatedCues = new Map<string, string>();

// === Initialization ===

async function initialize(): Promise<void> {
  if (isInitialized) return;

  console.log('[YouTube Translator] Initializing...');

  const messenger = await createMessengerWithFallback();
  const cache = createTranslationCache();

  translator = createTranslator(messenger, cache);
  wordBook = createWordBookService(messenger);
  toast = createToast();

  isInitialized = true;

  // Start monitoring for video player
  observeVideoPlayer();
  injectToggleButton();

  console.log('[YouTube Translator] Initialized');
}

// === Video Player Detection ===

function observeVideoPlayer(): void {
  // Initial check
  checkForVideoPlayer();

  // Observe for dynamic changes (SPA navigation)
  const observer = new MutationObserver(() => {
    checkForVideoPlayer();
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
  });
}

function checkForVideoPlayer(): void {
  const video = document.querySelector('video.html5-main-video') as HTMLVideoElement;

  if (video && video !== currentVideo) {
    currentVideo = video;
    console.log('[YouTube Translator] Video player found');
    setupSubtitleTracking(video);
  }
}

// === Subtitle Tracking ===

function setupSubtitleTracking(video: HTMLVideoElement): void {
  // Clean up previous observer
  if (subtitleObserver) {
    subtitleObserver.disconnect();
  }

  // Watch for subtitle track changes
  const textTracks = video.textTracks;

  // Handle existing tracks
  for (let i = 0; i < textTracks.length; i++) {
    const track = textTracks[i];
    if (track.kind === 'subtitles' || track.kind === 'captions') {
      watchTrack(track);
    }
  }

  // Listen for new tracks being added
  textTracks.addEventListener('addtrack', (event) => {
    const track = event.track;
    if (track && (track.kind === 'subtitles' || track.kind === 'captions')) {
      watchTrack(track);
    }
  });

  // Also observe YouTube's custom subtitle container
  observeYouTubeSubtitles();
}

function watchTrack(track: TextTrack): void {
  console.log('[YouTube Translator] Watching track:', track.label, track.language);

  track.addEventListener('cuechange', () => {
    if (!isEnabled || track.mode === 'disabled') return;

    const activeCues = track.activeCues;
    if (activeCues && activeCues.length > 0) {
      const cue = activeCues[0] as VTTCue;
      handleSubtitleCue(cue.text);
    } else {
      hideSubtitleOverlay();
    }
  });
}

// === YouTube Custom Subtitle Observer ===

function observeYouTubeSubtitles(): void {
  // YouTube uses a custom subtitle container
  const subtitleContainer = document.querySelector('.ytp-caption-window-container');

  if (!subtitleContainer) {
    // Retry after a short delay
    setTimeout(observeYouTubeSubtitles, 1000);
    return;
  }

  console.log('[YouTube Translator] Found YouTube subtitle container');

  subtitleObserver = new MutationObserver((mutations) => {
    if (!isEnabled) return;

    for (const mutation of mutations) {
      if (mutation.type === 'childList' || mutation.type === 'characterData') {
        const captionWindow = document.querySelector('.ytp-caption-window-bottom, .ytp-caption-window-top');
        if (captionWindow) {
          const text = captionWindow.textContent?.trim();
          if (text) {
            handleSubtitleCue(text);
          } else {
            hideSubtitleOverlay();
          }
        }
      }
    }
  });

  subtitleObserver.observe(subtitleContainer, {
    childList: true,
    subtree: true,
    characterData: true,
  });
}

// === Subtitle Translation ===

async function handleSubtitleCue(text: string): Promise<void> {
  if (!text || text.trim().length === 0) {
    hideSubtitleOverlay();
    return;
  }

  const trimmedText = text.trim();

  // Check if already translated
  const cached = translatedCues.get(trimmedText);
  if (cached) {
    showSubtitleOverlay(trimmedText, cached);
    return;
  }

  // Show original while translating
  showSubtitleOverlay(trimmedText, '翻译中...');

  try {
    const translation = await translator.translate(trimmedText);
    translatedCues.set(trimmedText, translation);
    showSubtitleOverlay(trimmedText, translation);
  } catch (error) {
    console.error('[YouTube Translator] Translation error:', error);
    // Show original only on error
    showSubtitleOverlay(trimmedText, '');
  }
}

// === Subtitle Overlay UI ===

function createSubtitleContainer(): HTMLDivElement {
  let container = document.getElementById(SUBTITLE_CONTAINER_ID) as HTMLDivElement;

  if (!container) {
    container = document.createElement('div');
    container.id = SUBTITLE_CONTAINER_ID;

    // Use Shadow DOM for style isolation
    const shadow = container.attachShadow({ mode: 'closed' });
    shadow.innerHTML = `
      <style>
        :host {
          all: initial;
          position: fixed;
          bottom: 80px;
          left: 50%;
          transform: translateX(-50%);
          z-index: 2147483647;
          pointer-events: none;
        }
        .subtitle-box {
          background: rgba(0, 0, 0, 0.85);
          border-radius: 8px;
          padding: 12px 20px;
          max-width: 80vw;
          text-align: center;
          pointer-events: auto;
        }
        .original {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          font-size: 20px;
          color: #ffffff;
          line-height: 1.4;
          margin-bottom: 8px;
          text-shadow: 1px 1px 2px rgba(0,0,0,0.5);
        }
        .translation {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          font-size: 18px;
          color: #ffd700;
          line-height: 1.4;
          text-shadow: 1px 1px 2px rgba(0,0,0,0.5);
        }
        .translation:empty {
          display: none;
        }
        .hidden {
          display: none;
        }
      </style>
      <div class="subtitle-box hidden">
        <div class="original"></div>
        <div class="translation"></div>
      </div>
    `;

    // Find YouTube player container
    const playerContainer = document.querySelector('.html5-video-player');
    if (playerContainer) {
      playerContainer.appendChild(container);
    } else {
      document.body.appendChild(container);
    }
  }

  return container;
}

function showSubtitleOverlay(original: string, translation: string): void {
  const container = createSubtitleContainer();
  const shadow = container.shadowRoot;
  if (!shadow) return;

  const box = shadow.querySelector('.subtitle-box');
  const originalEl = shadow.querySelector('.original');
  const translationEl = shadow.querySelector('.translation');

  if (box && originalEl && translationEl) {
    originalEl.textContent = original;
    translationEl.textContent = translation;
    box.classList.remove('hidden');
  }
}

function hideSubtitleOverlay(): void {
  const container = document.getElementById(SUBTITLE_CONTAINER_ID);
  if (!container) return;

  const shadow = container.shadowRoot;
  if (!shadow) return;

  const box = shadow.querySelector('.subtitle-box');
  if (box) {
    box.classList.add('hidden');
  }
}

// === Toggle Button ===

function injectToggleButton(): void {
  // Wait for YouTube controls to load
  const checkControls = setInterval(() => {
    const rightControls = document.querySelector('.ytp-right-controls');
    if (rightControls && !document.getElementById(SUBTITLE_TOGGLE_ID)) {
      clearInterval(checkControls);
      createToggleButton(rightControls);
    }
  }, 1000);
}

function createToggleButton(container: Element): void {
  const button = document.createElement('button');
  button.id = SUBTITLE_TOGGLE_ID;
  button.className = 'ytp-button';
  button.title = '双语字幕翻译';
  button.setAttribute('aria-label', '双语字幕翻译');

  // Use Shadow DOM for the button content
  const shadow = button.attachShadow({ mode: 'closed' });
  shadow.innerHTML = `
    <style>
      :host {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 48px;
        height: 48px;
        cursor: pointer;
      }
      .icon {
        width: 24px;
        height: 24px;
        fill: #fff;
        opacity: ${isEnabled ? '1' : '0.5'};
        transition: opacity 0.2s;
      }
      :host(:hover) .icon {
        opacity: 1;
      }
    </style>
    <svg class="icon" viewBox="0 0 24 24">
      <path d="M12.87 15.07l-2.54-2.51.03-.03A17.52 17.52 0 0014.07 6H17V4h-7V2H8v2H1v2h11.17C11.5 7.92 10.44 9.75 9 11.35 8.07 10.32 7.3 9.19 6.69 8h-2c.73 1.63 1.73 3.17 2.98 4.56l-5.09 5.02L4 19l5-5 3.11 3.11.76-2.04zM18.5 10h-2L12 22h2l1.12-3h4.75L21 22h2l-4.5-12zm-2.62 7l1.62-4.33L19.12 17h-3.24z"/>
    </svg>
  `;

  button.addEventListener('click', () => {
    isEnabled = !isEnabled;
    updateToggleButtonState(button);

    if (isEnabled) {
      toast.success('双语字幕已开启');
    } else {
      toast.info('双语字幕已关闭');
      hideSubtitleOverlay();
    }
  });

  // Insert before fullscreen button
  const fullscreenBtn = container.querySelector('.ytp-fullscreen-button');
  if (fullscreenBtn) {
    container.insertBefore(button, fullscreenBtn);
  } else {
    container.appendChild(button);
  }
}

function updateToggleButtonState(button: HTMLButtonElement): void {
  const shadow = button.shadowRoot;
  if (!shadow) return;

  const icon = shadow.querySelector('.icon') as SVGElement;
  if (icon) {
    icon.style.opacity = isEnabled ? '1' : '0.5';
  }
}

// === Word Saving (Double-click on subtitle) ===

function setupWordSaving(): void {
  document.addEventListener('dblclick', async (event) => {
    const target = event.target as HTMLElement;

    // Check if clicking on our subtitle overlay
    const container = document.getElementById(SUBTITLE_CONTAINER_ID);
    if (!container?.contains(target)) return;

    const selection = window.getSelection();
    const selectedText = selection?.toString().trim();

    if (!selectedText || selectedText.length === 0) return;
    if (selectedText.length > 100) return;

    try {
      const translation = await translator.translate(selectedText);

      const word = createWordEntry(selectedText, translation, window.location.href);
      word.source = 'video';

      await wordBook.save(word);
      toast.success('已收藏到单词本');
    } catch (error) {
      if (error instanceof TranslatorError && error.code === ErrorCode.WORD_ALREADY_EXISTS) {
        toast.info('单词已存在');
      } else {
        toast.error('保存失败');
      }
    }
  });
}

// === Message Handler ===

interface YouTubeMessage {
  type: 'TOGGLE_YOUTUBE_SUBTITLE' | 'GET_YOUTUBE_SUBTITLE_STATUS';
}

chrome.runtime.onMessage.addListener(
  (message: YouTubeMessage, _sender, sendResponse) => {
    if (message.type === 'TOGGLE_YOUTUBE_SUBTITLE') {
      isEnabled = !isEnabled;
      const toggleBtn = document.getElementById(SUBTITLE_TOGGLE_ID) as HTMLButtonElement;
      if (toggleBtn) {
        updateToggleButtonState(toggleBtn);
      }
      sendResponse({ success: true, enabled: isEnabled });
      return true;
    }

    if (message.type === 'GET_YOUTUBE_SUBTITLE_STATUS') {
      sendResponse({ success: true, enabled: isEnabled });
      return true;
    }

    return false;
  }
);

// === Cleanup on Navigation ===

function cleanup(): void {
  if (subtitleObserver) {
    subtitleObserver.disconnect();
    subtitleObserver = null;
  }

  const container = document.getElementById(SUBTITLE_CONTAINER_ID);
  if (container) {
    container.remove();
  }

  const toggle = document.getElementById(SUBTITLE_TOGGLE_ID);
  if (toggle) {
    toggle.remove();
  }

  currentVideo = null;
  translatedCues.clear();
}

// Handle YouTube SPA navigation
window.addEventListener('yt-navigate-start', cleanup);

// === Entry Point ===

// Only run on YouTube watch pages
if (window.location.hostname.includes('youtube.com')) {
  initialize().catch((error) => {
    console.error('[YouTube Translator] Failed to initialize:', error);
  });

  setupWordSaving();
}

// Export for testing
export {
  handleSubtitleCue,
  showSubtitleOverlay,
  hideSubtitleOverlay,
  cleanup,
};
