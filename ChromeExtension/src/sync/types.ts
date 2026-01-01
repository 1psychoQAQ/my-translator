/**
 * Cloud Sync Types
 */

import type { StoredWord } from '../backends/types';

export interface SyncMetadata {
  /** Last sync timestamp */
  lastSyncAt: number;
  /** Device identifier */
  deviceId: string;
  /** Sync provider */
  provider: SyncProvider;
  /** Remote resource ID (e.g., Gist ID) */
  remoteId?: string;
}

export type SyncProvider = 'gist' | 'local';

export interface SyncData {
  /** Schema version for forward compatibility */
  version: number;
  /** Sync metadata */
  metadata: {
    exportedAt: number;
    deviceId: string;
    wordCount: number;
  };
  /** Word entries */
  words: StoredWord[];
}

export interface SyncResult {
  success: boolean;
  /** Number of words added locally */
  added: number;
  /** Number of words updated locally */
  updated: number;
  /** Number of words pushed to remote */
  pushed: number;
  /** Any conflicts that occurred */
  conflicts: SyncConflict[];
  /** Error message if failed */
  error?: string;
}

export interface SyncConflict {
  word: string;
  localVersion: StoredWord;
  remoteVersion: StoredWord;
  resolution: 'local' | 'remote' | 'merge';
}

export interface SyncService {
  /** Provider name */
  readonly provider: SyncProvider;

  /** Check if sync is configured */
  isConfigured(): Promise<boolean>;

  /** Configure sync (e.g., set API token) */
  configure(config: SyncConfig): Promise<void>;

  /** Push local data to remote */
  push(data: SyncData): Promise<{ remoteId: string }>;

  /** Pull remote data */
  pull(): Promise<SyncData | null>;

  /** Full sync (pull + merge + push) */
  sync(localWords: StoredWord[]): Promise<SyncResult>;

  /** Clear sync configuration */
  disconnect(): Promise<void>;
}

export interface SyncConfig {
  /** GitHub Personal Access Token (for Gist) */
  token?: string;
  /** Existing Gist ID to use */
  gistId?: string;
  /** Whether to create private gist */
  private?: boolean;
}

export const SYNC_DATA_VERSION = 1;

export function createSyncData(
  words: StoredWord[],
  deviceId: string
): SyncData {
  return {
    version: SYNC_DATA_VERSION,
    metadata: {
      exportedAt: Date.now(),
      deviceId,
      wordCount: words.length,
    },
    words,
  };
}

export async function generateDeviceId(): Promise<string> {
  // Generate a persistent device ID using chrome.storage.local
  const result = await chrome.storage.local.get('translator_device_id');
  if (result.translator_device_id) {
    return result.translator_device_id as string;
  }
  const newId = `device_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  await chrome.storage.local.set({ translator_device_id: newId });
  return newId;
}
