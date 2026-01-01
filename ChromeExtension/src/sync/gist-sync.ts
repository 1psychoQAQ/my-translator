/**
 * GitHub Gist Sync Service
 *
 * Uses GitHub Gist as a free cloud storage for word book sync.
 * Requires a GitHub Personal Access Token with 'gist' scope.
 */

import type { StoredWord } from '../backends/types';
import type {
  SyncService,
  SyncConfig,
  SyncData,
  SyncResult,
  SyncConflict,
} from './types';
import { createSyncData, generateDeviceId } from './types';

const GIST_FILENAME = 'translator-wordbook.json';
const CONFIG_KEY = 'translator_gist_config';

interface GistConfig {
  token: string;
  gistId?: string;
  private: boolean;
}

interface GistFile {
  filename: string;
  content: string;
  raw_url?: string;
}

interface GistResponse {
  id: string;
  files: Record<string, GistFile>;
  public: boolean;
  description: string;
  created_at: string;
  updated_at: string;
}

async function loadConfig(): Promise<GistConfig | null> {
  try {
    const result = await chrome.storage.local.get(CONFIG_KEY);
    return (result[CONFIG_KEY] as GistConfig) || null;
  } catch {
    return null;
  }
}

async function saveConfig(config: GistConfig): Promise<void> {
  await chrome.storage.local.set({ [CONFIG_KEY]: config });
}

async function clearConfig(): Promise<void> {
  await chrome.storage.local.remove(CONFIG_KEY);
}

export function createGistSyncService(): SyncService {

  async function apiRequest<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const config = await loadConfig();
    if (!config?.token) {
      throw new Error('Gist sync not configured');
    }

    const response = await fetch(`https://api.github.com${endpoint}`, {
      ...options,
      headers: {
        Accept: 'application/vnd.github+json',
        Authorization: `Bearer ${config.token}`,
        'X-GitHub-Api-Version': '2022-11-28',
        ...options.headers,
      },
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`GitHub API error: ${response.status} - ${error}`);
    }

    return response.json() as Promise<T>;
  }

  async function createGist(data: SyncData, isPrivate: boolean): Promise<string> {
    const response = await apiRequest<GistResponse>('/gists', {
      method: 'POST',
      body: JSON.stringify({
        description: 'Translator Word Book Sync',
        public: !isPrivate,
        files: {
          [GIST_FILENAME]: {
            content: JSON.stringify(data, null, 2),
          },
        },
      }),
    });

    return response.id;
  }

  async function updateGist(gistId: string, data: SyncData): Promise<void> {
    await apiRequest<GistResponse>(`/gists/${gistId}`, {
      method: 'PATCH',
      body: JSON.stringify({
        files: {
          [GIST_FILENAME]: {
            content: JSON.stringify(data, null, 2),
          },
        },
      }),
    });
  }

  async function getGist(gistId: string): Promise<SyncData | null> {
    try {
      const response = await apiRequest<GistResponse>(`/gists/${gistId}`);
      const file = response.files[GIST_FILENAME];

      if (!file?.content) {
        return null;
      }

      return JSON.parse(file.content) as SyncData;
    } catch {
      return null;
    }
  }

  function mergeWords(
    local: StoredWord[],
    remote: StoredWord[]
  ): { merged: StoredWord[]; conflicts: SyncConflict[] } {
    const merged: StoredWord[] = [];
    const conflicts: SyncConflict[] = [];
    const remoteMap = new Map(remote.map((w) => [w.id, w]));
    const processedIds = new Set<string>();

    // Process local words
    for (const localWord of local) {
      processedIds.add(localWord.id);
      const remoteWord = remoteMap.get(localWord.id);

      if (!remoteWord) {
        // Local only - keep it
        merged.push(localWord);
      } else if (localWord.createdAt === remoteWord.createdAt) {
        // Same word - keep local (or remote, they're the same)
        merged.push(localWord);
      } else {
        // Conflict - use newer version
        const newer =
          localWord.createdAt > remoteWord.createdAt ? localWord : remoteWord;
        merged.push(newer);
        conflicts.push({
          word: localWord.text,
          localVersion: localWord,
          remoteVersion: remoteWord,
          resolution: newer === localWord ? 'local' : 'remote',
        });
      }
    }

    // Add remote-only words
    for (const remoteWord of remote) {
      if (!processedIds.has(remoteWord.id)) {
        merged.push(remoteWord);
      }
    }

    // Sort by createdAt descending (newest first)
    merged.sort((a, b) => b.createdAt - a.createdAt);

    return { merged, conflicts };
  }

  return {
    provider: 'gist',

    async isConfigured(): Promise<boolean> {
      const config = await loadConfig();
      return !!config?.token;
    },

    async configure(config: SyncConfig): Promise<void> {
      if (!config.token) {
        throw new Error('GitHub token is required');
      }

      // Validate token by making a test request
      const response = await fetch('https://api.github.com/user', {
        headers: {
          Authorization: `Bearer ${config.token}`,
          Accept: 'application/vnd.github+json',
        },
      });

      if (!response.ok) {
        throw new Error('Invalid GitHub token');
      }

      await saveConfig({
        token: config.token,
        gistId: config.gistId,
        private: config.private ?? true,
      });
    },

    async push(data: SyncData): Promise<{ remoteId: string }> {
      const config = await loadConfig();
      if (!config) {
        throw new Error('Gist sync not configured');
      }

      if (config.gistId) {
        await updateGist(config.gistId, data);
        return { remoteId: config.gistId };
      } else {
        const gistId = await createGist(data, config.private);
        await saveConfig({ ...config, gistId });
        return { remoteId: gistId };
      }
    },

    async pull(): Promise<SyncData | null> {
      const config = await loadConfig();
      if (!config?.gistId) {
        return null;
      }

      return getGist(config.gistId);
    },

    async sync(localWords: StoredWord[]): Promise<SyncResult> {
      try {
        const config = await loadConfig();
        if (!config) {
          return {
            success: false,
            added: 0,
            updated: 0,
            pushed: 0,
            conflicts: [],
            error: 'Gist sync not configured',
          };
        }

        // Pull remote data
        let remoteData: SyncData | null = null;
        if (config.gistId) {
          remoteData = await getGist(config.gistId);
        }

        const remoteWords = remoteData?.words || [];

        // Merge local and remote
        const { merged, conflicts } = mergeWords(localWords, remoteWords);

        // Calculate stats
        const localIds = new Set(localWords.map((w) => w.id));
        const remoteIds = new Set(remoteWords.map((w) => w.id));

        const added = merged.filter(
          (w) => !localIds.has(w.id) && remoteIds.has(w.id)
        ).length;
        const pushed = merged.filter(
          (w) => localIds.has(w.id) && !remoteIds.has(w.id)
        ).length;

        // Push merged data
        const deviceId = await generateDeviceId();
        const syncData = createSyncData(merged, deviceId);
        const { remoteId } = await this.push(syncData);

        // Update config with gist ID if new
        if (!config.gistId) {
          await saveConfig({ ...config, gistId: remoteId });
        }

        return {
          success: true,
          added,
          updated: conflicts.length,
          pushed,
          conflicts,
        };
      } catch (error) {
        return {
          success: false,
          added: 0,
          updated: 0,
          pushed: 0,
          conflicts: [],
          error: error instanceof Error ? error.message : 'Sync failed',
        };
      }
    },

    async disconnect(): Promise<void> {
      await clearConfig();
    },
  };
}
