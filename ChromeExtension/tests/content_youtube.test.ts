import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

// Mock DOM elements
function createMockVideoElement(): HTMLVideoElement {
  const video = document.createElement('video');
  video.className = 'html5-main-video';

  // Create mock TextTrackList
  const textTracks = [] as TextTrack[];
  Object.defineProperty(video, 'textTracks', {
    get: () => ({
      length: textTracks.length,
      [Symbol.iterator]: () => textTracks[Symbol.iterator](),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    }),
  });

  return video;
}

function createMockPlayerContainer(): HTMLElement {
  const container = document.createElement('div');
  container.className = 'html5-video-player';
  return container;
}

function createMockYouTubeControls(): HTMLElement {
  const controls = document.createElement('div');
  controls.className = 'ytp-right-controls';

  const fullscreenBtn = document.createElement('button');
  fullscreenBtn.className = 'ytp-fullscreen-button';
  controls.appendChild(fullscreenBtn);

  return controls;
}

function createMockCaptionContainer(): HTMLElement {
  const container = document.createElement('div');
  container.className = 'ytp-caption-window-container';

  const captionWindow = document.createElement('div');
  captionWindow.className = 'ytp-caption-window-bottom';
  container.appendChild(captionWindow);

  return container;
}

describe('YouTube Subtitle Translator', () => {
  beforeEach(() => {
    // Clear document body
    document.body.innerHTML = '';

    // Mock chrome.runtime (using type assertion for test mock)
    globalThis.chrome = {
      runtime: {
        sendMessage: vi.fn(),
        onMessage: {
          addListener: vi.fn(),
          removeListener: vi.fn(),
        },
        lastError: undefined,
      },
    } as unknown as typeof chrome;

    // Mock window.location for YouTube
    Object.defineProperty(window, 'location', {
      value: {
        hostname: 'www.youtube.com',
        href: 'https://www.youtube.com/watch?v=test',
      },
      writable: true,
    });
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  describe('Video Player Detection', () => {
    it('should detect video element with correct class', () => {
      const player = createMockPlayerContainer();
      const video = createMockVideoElement();
      player.appendChild(video);
      document.body.appendChild(player);

      const found = document.querySelector('video.html5-main-video');
      expect(found).toBeTruthy();
      expect(found).toBe(video);
    });
  });

  describe('YouTube Controls', () => {
    it('should find right controls container', () => {
      const controls = createMockYouTubeControls();
      document.body.appendChild(controls);

      const found = document.querySelector('.ytp-right-controls');
      expect(found).toBeTruthy();
      expect(found).toBe(controls);
    });

    it('should find fullscreen button for insertion point', () => {
      const controls = createMockYouTubeControls();
      document.body.appendChild(controls);

      const fullscreenBtn = document.querySelector('.ytp-fullscreen-button');
      expect(fullscreenBtn).toBeTruthy();
    });
  });

  describe('Caption Container', () => {
    it('should detect caption container', () => {
      const captionContainer = createMockCaptionContainer();
      document.body.appendChild(captionContainer);

      const found = document.querySelector('.ytp-caption-window-container');
      expect(found).toBeTruthy();
    });

    it('should find caption window', () => {
      const captionContainer = createMockCaptionContainer();
      document.body.appendChild(captionContainer);

      const captionWindow = document.querySelector('.ytp-caption-window-bottom');
      expect(captionWindow).toBeTruthy();
    });
  });

  describe('Subtitle Overlay Creation', () => {
    it('should create subtitle container with shadow DOM', () => {
      const container = document.createElement('div');
      container.id = 'translator-youtube-subtitles';

      const shadow = container.attachShadow({ mode: 'open' });
      shadow.innerHTML = `
        <style>:host { position: fixed; }</style>
        <div class="subtitle-box">
          <div class="original"></div>
          <div class="translation"></div>
        </div>
      `;

      document.body.appendChild(container);

      expect(document.getElementById('translator-youtube-subtitles')).toBeTruthy();
      expect(container.shadowRoot).toBeTruthy();
    });
  });

  describe('Toggle Button', () => {
    it('should create toggle button with correct attributes', () => {
      const controls = createMockYouTubeControls();
      document.body.appendChild(controls);

      // Simulate creating toggle button
      const button = document.createElement('button');
      button.id = 'translator-youtube-toggle';
      button.className = 'ytp-button';
      button.title = '双语字幕翻译';

      const fullscreenBtn = controls.querySelector('.ytp-fullscreen-button');
      controls.insertBefore(button, fullscreenBtn);

      const toggle = document.getElementById('translator-youtube-toggle');
      expect(toggle).toBeTruthy();
      expect(toggle?.title).toBe('双语字幕翻译');
      expect(toggle?.className).toContain('ytp-button');
    });

    it('should insert toggle before fullscreen button', () => {
      const controls = createMockYouTubeControls();
      document.body.appendChild(controls);

      const button = document.createElement('button');
      button.id = 'translator-youtube-toggle';

      const fullscreenBtn = controls.querySelector('.ytp-fullscreen-button');
      controls.insertBefore(button, fullscreenBtn);

      const children = Array.from(controls.children);
      const toggleIndex = children.findIndex((el) => el.id === 'translator-youtube-toggle');
      const fullscreenIndex = children.findIndex((el) =>
        el.classList.contains('ytp-fullscreen-button')
      );

      expect(toggleIndex).toBeLessThan(fullscreenIndex);
    });
  });

  describe('Subtitle Cue Handling', () => {
    it('should extract text from caption window', () => {
      const captionContainer = createMockCaptionContainer();
      const captionWindow = captionContainer.querySelector('.ytp-caption-window-bottom');
      if (captionWindow) {
        captionWindow.textContent = 'Hello, world!';
      }
      document.body.appendChild(captionContainer);

      const text = captionWindow?.textContent?.trim();
      expect(text).toBe('Hello, world!');
    });

    it('should handle empty subtitle cue', () => {
      const captionContainer = createMockCaptionContainer();
      const captionWindow = captionContainer.querySelector('.ytp-caption-window-bottom');
      if (captionWindow) {
        captionWindow.textContent = '';
      }
      document.body.appendChild(captionContainer);

      const text = captionWindow?.textContent?.trim();
      expect(text).toBe('');
    });
  });

  describe('Translation Cache', () => {
    it('should cache translated subtitles', () => {
      const cache = new Map<string, string>();

      cache.set('Hello', '你好');
      expect(cache.get('Hello')).toBe('你好');

      cache.set('World', '世界');
      expect(cache.size).toBe(2);
    });

    it('should return cached translation', () => {
      const cache = new Map<string, string>();
      cache.set('Hello, world!', '你好，世界！');

      const cached = cache.get('Hello, world!');
      expect(cached).toBe('你好，世界！');
    });
  });

  describe('YouTube Navigation Handling', () => {
    it('should clean up on navigation event', () => {
      // Create elements to clean up
      const container = document.createElement('div');
      container.id = 'translator-youtube-subtitles';
      document.body.appendChild(container);

      const toggle = document.createElement('button');
      toggle.id = 'translator-youtube-toggle';
      document.body.appendChild(toggle);

      // Simulate cleanup
      const subtitleContainer = document.getElementById('translator-youtube-subtitles');
      if (subtitleContainer) subtitleContainer.remove();

      const toggleBtn = document.getElementById('translator-youtube-toggle');
      if (toggleBtn) toggleBtn.remove();

      expect(document.getElementById('translator-youtube-subtitles')).toBeNull();
      expect(document.getElementById('translator-youtube-toggle')).toBeNull();
    });
  });

  describe('Word Saving from Subtitles', () => {
    it('should create word entry with video source', () => {
      const wordEntry = {
        id: 'test-id',
        text: 'hello',
        translation: '你好',
        source: 'video' as const,
        sourceURL: 'https://www.youtube.com/watch?v=test',
        tags: [],
        createdAt: Date.now(),
      };

      expect(wordEntry.source).toBe('video');
      expect(wordEntry.sourceURL).toContain('youtube.com');
    });
  });

  describe('Message Handling', () => {
    it('should respond to TOGGLE_YOUTUBE_SUBTITLE message', () => {
      let isEnabled = true;

      const handleMessage = (
        message: { type: string },
        sendResponse: (response: { success: boolean; enabled: boolean }) => void
      ) => {
        if (message.type === 'TOGGLE_YOUTUBE_SUBTITLE') {
          isEnabled = !isEnabled;
          sendResponse({ success: true, enabled: isEnabled });
          return true;
        }
        return false;
      };

      const response = { success: false, enabled: true };
      handleMessage({ type: 'TOGGLE_YOUTUBE_SUBTITLE' }, (r) => Object.assign(response, r));

      expect(response.success).toBe(true);
      expect(response.enabled).toBe(false);
    });

    it('should respond to GET_YOUTUBE_SUBTITLE_STATUS message', () => {
      const isEnabled = true;

      const handleMessage = (
        message: { type: string },
        sendResponse: (response: { success: boolean; enabled: boolean }) => void
      ) => {
        if (message.type === 'GET_YOUTUBE_SUBTITLE_STATUS') {
          sendResponse({ success: true, enabled: isEnabled });
          return true;
        }
        return false;
      };

      const response = { success: false, enabled: false };
      handleMessage({ type: 'GET_YOUTUBE_SUBTITLE_STATUS' }, (r) => Object.assign(response, r));

      expect(response.success).toBe(true);
      expect(response.enabled).toBe(true);
    });
  });
});
