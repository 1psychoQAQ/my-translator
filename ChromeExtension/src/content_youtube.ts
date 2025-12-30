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

// Debounce timer for subtitle updates
let subtitleDebounceTimer: ReturnType<typeof setTimeout> | null = null;
let lastSubtitleText = ''; // Last text we started processing
let pendingSubtitleText = ''; // Text currently building up (may be incomplete)
let currentDisplayedText = ''; // What's currently shown on screen
let isTranslating = false; // Prevent overlapping translations
let useTextTrackAPI = false; // True if TextTrack API is providing cues
let lastTextTrackCueTime = 0; // Timestamp of last TextTrack cue
const DEBOUNCE_DELAY = 800; // ms - wait for subtitle to stabilize (MutationObserver fallback)
const TEXT_TRACK_TIMEOUT = 3000; // ms - if no TextTrack cue for this long, fall back to MutationObserver

// Sentence buffering - combine cues into complete sentences
let sentenceBuffer = ''; // Buffer to accumulate cues
let sentenceTimer: ReturnType<typeof setTimeout> | null = null;
const SENTENCE_TIMEOUT = 1500; // ms - max wait time for sentence completion
const SENTENCE_END_PATTERN = /[.!?。！？；;]$/; // Punctuation that ends a sentence

// === Initialization ===

async function initialize(): Promise<void> {
  if (isInitialized) return;

  const messenger = await createMessengerWithFallback();
  const cache = createTranslationCache();

  translator = createTranslator(messenger, cache);
  wordBook = createWordBookService(messenger);
  toast = createToast();

  isInitialized = true;

  // Start monitoring for video player
  observeVideoPlayer();
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
  track.addEventListener('cuechange', () => {
    if (!isEnabled || track.mode === 'disabled') return;

    const activeCues = track.activeCues;
    if (activeCues && activeCues.length > 0) {
      const cue = activeCues[0] as VTTCue;
      // TextTrack API provides complete cues - process immediately without debounce
      handleTextTrackCue(cue.text);
    } else {
      // Cue ended - hide after a short delay
      setTimeout(() => {
        if (!pendingSubtitleText && !isTranslating) {
          hideSubtitleOverlay();
          currentDisplayedText = '';
        }
      }, 300);
    }
  });
}

// Handle cues from TextTrack API - buffer into complete sentences
function handleTextTrackCue(text: string): void {
  if (!isEnabled || !text || text.trim().length === 0) return;

  const trimmedText = text.trim();

  // Mark that TextTrack API is working
  useTextTrackAPI = true;
  lastTextTrackCueTime = Date.now();

  // Clear any pending MutationObserver debounce
  if (subtitleDebounceTimer) {
    clearTimeout(subtitleDebounceTimer);
    subtitleDebounceTimer = null;
  }

  // Add to sentence buffer
  if (sentenceBuffer && !sentenceBuffer.endsWith(' ')) {
    sentenceBuffer += ' ';
  }
  sentenceBuffer += trimmedText;

  // Clear previous sentence timer
  if (sentenceTimer) {
    clearTimeout(sentenceTimer);
    sentenceTimer = null;
  }

  // Check if sentence is complete (ends with punctuation)
  const isSentenceComplete = SENTENCE_END_PATTERN.test(sentenceBuffer);

  if (isSentenceComplete) {
    // Sentence complete - translate immediately
    processBufferedSentence();
  } else {
    // Wait for more cues or timeout
    sentenceTimer = setTimeout(() => {
      // Timeout - translate what we have
      processBufferedSentence();
    }, SENTENCE_TIMEOUT);
  }
}

// Process the buffered sentence
function processBufferedSentence(): void {
  if (!sentenceBuffer) return;

  const sentence = sentenceBuffer.trim();
  sentenceBuffer = '';

  if (sentenceTimer) {
    clearTimeout(sentenceTimer);
    sentenceTimer = null;
  }

  // Skip if same as last
  if (sentence === lastSubtitleText) return;

  lastSubtitleText = sentence;
  pendingSubtitleText = sentence;

  // Check cache first
  const cached = translatedCues.get(sentence);
  if (cached) {
    currentDisplayedText = sentence;
    showSubtitleOverlay(sentence, cached);
    return;
  }

  // Process translation
  processSubtitleTranslation(sentence);
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

  subtitleObserver = new MutationObserver((mutations) => {
    if (!isEnabled) return;

    // If TextTrack API is working recently, ignore MutationObserver
    // This prevents duplicate/conflicting updates
    if (useTextTrackAPI && Date.now() - lastTextTrackCueTime < TEXT_TRACK_TIMEOUT) {
      return;
    }

    for (const mutation of mutations) {
      if (mutation.type === 'childList' || mutation.type === 'characterData') {
        const captionWindow = document.querySelector('.ytp-caption-window-bottom, .ytp-caption-window-top');
        if (captionWindow) {
          const text = captionWindow.textContent?.trim();
          if (text) {
            // MutationObserver fallback - needs debouncing since text may be building up
            handleMutationObserverCue(text);
          } else {
            // Text disappeared
            handleMutationObserverCue('');
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

// MutationObserver fallback handler - needs debouncing
// YouTube subtitles may build up word by word when TextTrack API isn't available
// We need to wait for the COMPLETE sentence before translating
function handleMutationObserverCue(text: string): void {
  if (!isEnabled) {
    return;
  }

  if (!text || text.trim().length === 0) {
    // Subtitle disappeared - but don't hide immediately
    // The subtitle might just be transitioning between cues
    if (subtitleDebounceTimer) {
      clearTimeout(subtitleDebounceTimer);
      subtitleDebounceTimer = null;
    }

    // Only hide after a delay, and only if nothing new came in
    pendingSubtitleText = '';
    if (!isTranslating) {
      subtitleDebounceTimer = setTimeout(() => {
        if (pendingSubtitleText === '') {
          hideSubtitleOverlay();
          currentDisplayedText = '';
          lastSubtitleText = '';
        }
      }, 800);
    }
    return;
  }

  const trimmedText = text.trim();

  // Skip if exactly same as what we're already processing
  if (trimmedText === pendingSubtitleText) {
    return;
  }

  // Update pending text - this is what we're waiting to stabilize
  pendingSubtitleText = trimmedText;

  // Clear previous timer - text changed, restart the wait
  if (subtitleDebounceTimer) {
    clearTimeout(subtitleDebounceTimer);
    subtitleDebounceTimer = null;
  }

  // Check cache first - if cached, show immediately
  const cached = translatedCues.get(trimmedText);
  if (cached) {
    lastSubtitleText = trimmedText;
    currentDisplayedText = trimmedText;
    showSubtitleOverlay(trimmedText, cached);
    return;
  }

  // Wait for subtitle to stabilize (no changes for DEBOUNCE_DELAY ms)
  // This ensures we capture the complete sentence, not partial words
  subtitleDebounceTimer = setTimeout(() => {
    // Double check the text hasn't changed while we waited
    if (pendingSubtitleText === trimmedText) {
      lastSubtitleText = trimmedText;
      processSubtitleTranslation(trimmedText);
    }
  }, DEBOUNCE_DELAY);
}

// Process the actual translation
async function processSubtitleTranslation(text: string): Promise<void> {
  // Check cache again (might have been cached while waiting)
  const cached = translatedCues.get(text);
  if (cached) {
    currentDisplayedText = text;
    showSubtitleOverlay(text, cached);
    return;
  }

  // Mark as translating
  isTranslating = true;

  try {
    const translation = await translator.translate(text);
    translatedCues.set(text, translation);

    // Always show translation when ready
    // New translations will naturally replace old ones
    // This prevents the "translation appears on next cue" problem
    currentDisplayedText = text;
    showSubtitleOverlay(text, translation);
  } catch {
    // On error, show original without translation
    currentDisplayedText = text;
    showSubtitleOverlay(text, '');
  } finally {
    isTranslating = false;
  }
}

// === Subtitle Overlay UI ===

// Type for elements with stored shadow reference
type ElementWithShadow = HTMLElement & { _shadow?: ShadowRoot };

function createSubtitleContainer(): HTMLDivElement {
  let container = document.getElementById(SUBTITLE_CONTAINER_ID) as HTMLDivElement & { _shadow?: ShadowRoot };

  if (!container) {
    container = document.createElement('div') as HTMLDivElement & { _shadow?: ShadowRoot };
    container.id = SUBTITLE_CONTAINER_ID;

    // Use Shadow DOM for style isolation
    const shadow = container.attachShadow({ mode: 'closed' });
    shadow.innerHTML = `
      <style>
        :host {
          all: initial;
          display: block;
          width: 100%;
          margin: 12px 0;
          pointer-events: none;
        }
        .subtitle-box {
          background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
          border-radius: 8px;
          padding: 16px 24px;
          margin: 0 auto;
          max-width: 100%;
          text-align: center;
          pointer-events: auto;
          border: 1px solid rgba(255, 255, 255, 0.1);
          box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
          opacity: 1;
          transition: opacity 0.3s ease-out;
        }
        .subtitle-box.hidden {
          opacity: 0;
          pointer-events: none;
        }
        .original {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          font-size: 18px;
          color: #ffffff;
          line-height: 1.5;
          margin-bottom: 10px;
        }
        .translation {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          font-size: 16px;
          color: #ffd700;
          line-height: 1.5;
          min-height: 0;
        }
        .translation:empty {
          display: none;
        }
      </style>
      <div class="subtitle-box hidden">
        <div class="original"></div>
        <div class="translation"></div>
      </div>
    `;

    // Store shadow reference for later access (closed shadow DOM returns null for shadowRoot)
    container._shadow = shadow;

    // Insert below the video player
    const belowContainer = document.querySelector('#below');
    const playerContainer = document.querySelector('#player-container-outer, #player-container, #movie_player');

    if (belowContainer) {
      // Insert at the beginning of the below section
      belowContainer.insertBefore(container, belowContainer.firstChild);
    } else if (playerContainer?.parentElement) {
      // Insert after the player container
      playerContainer.parentElement.insertBefore(container, playerContainer.nextSibling);
    } else {
      document.body.appendChild(container);
    }
  }

  return container;
}

function showSubtitleOverlay(original: string, translation: string): void {
  const container = createSubtitleContainer() as ElementWithShadow;
  const shadow = container._shadow;
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
  const container = document.getElementById(SUBTITLE_CONTAINER_ID) as ElementWithShadow | null;
  if (!container) return;

  const shadow = container._shadow;
  if (!shadow) return;

  const box = shadow.querySelector('.subtitle-box');
  if (box) {
    box.classList.add('hidden');
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
      if (!isEnabled) {
        hideSubtitleOverlay();
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

  if (subtitleDebounceTimer) {
    clearTimeout(subtitleDebounceTimer);
    subtitleDebounceTimer = null;
  }

  const container = document.getElementById(SUBTITLE_CONTAINER_ID);
  if (container) {
    container.remove();
  }

  currentVideo = null;
  translatedCues.clear();
  lastSubtitleText = '';
  pendingSubtitleText = '';
  currentDisplayedText = '';
  isTranslating = false;
  useTextTrackAPI = false;
  lastTextTrackCueTime = 0;
  sentenceBuffer = '';
  if (sentenceTimer) {
    clearTimeout(sentenceTimer);
    sentenceTimer = null;
  }
}

function reinitialize(): void {
  // Only re-initialize on watch pages
  if (!window.location.pathname.startsWith('/watch')) {
    return;
  }

  // Re-inject elements
  checkForVideoPlayer();
}

// Handle YouTube SPA navigation
window.addEventListener('yt-navigate-start', cleanup);
window.addEventListener('yt-navigate-finish', reinitialize);

// === Entry Point ===

// Only run on YouTube watch pages
if (window.location.hostname.includes('youtube.com')) {
  initialize().catch(() => {
    // Silent fail
  });

  setupWordSaving();
}

// Export for testing
export {
  handleTextTrackCue,
  handleMutationObserverCue,
  processBufferedSentence,
  showSubtitleOverlay,
  hideSubtitleOverlay,
  cleanup,
};
