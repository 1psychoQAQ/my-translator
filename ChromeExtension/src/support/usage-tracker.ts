/**
 * Usage Tracker
 * Tracks translation usage to trigger "buy me a coffee" prompts
 */

import type { UsageStats, SupportStatus, CoffeePromptTrigger } from './types';
import {
  USAGE_STATS_KEY,
  SUPPORT_STATUS_KEY,
  PROMPT_MILESTONES,
} from './types';

const DEFAULT_USAGE_STATS: UsageStats = {
  translationCount: 0,
  wordsSaved: 0,
  firstUseAt: 0,
  lastPromptAt: 0,
};

const DEFAULT_SUPPORT_STATUS: SupportStatus = {
  isSupporter: false,
  dismissedUntil: 0,
};

async function getUsageStats(): Promise<UsageStats> {
  const result = await chrome.storage.local.get(USAGE_STATS_KEY);
  return (result[USAGE_STATS_KEY] as UsageStats) || { ...DEFAULT_USAGE_STATS };
}

async function setUsageStats(stats: UsageStats): Promise<void> {
  await chrome.storage.local.set({ [USAGE_STATS_KEY]: stats });
}

async function getSupportStatus(): Promise<SupportStatus> {
  const result = await chrome.storage.local.get(SUPPORT_STATUS_KEY);
  return (result[SUPPORT_STATUS_KEY] as SupportStatus) || { ...DEFAULT_SUPPORT_STATUS };
}

async function setSupportStatus(status: SupportStatus): Promise<void> {
  await chrome.storage.local.set({ [SUPPORT_STATUS_KEY]: status });
}

/**
 * Track a translation event
 * Returns whether to show coffee prompt
 */
export async function trackTranslation(): Promise<CoffeePromptTrigger> {
  const stats = await getUsageStats();
  const support = await getSupportStatus();

  // Increment count
  stats.translationCount += 1;

  // Set first use time if not set
  if (!stats.firstUseAt) {
    stats.firstUseAt = Date.now();
  }

  await setUsageStats(stats);

  // Already a supporter - never show prompt
  if (support.isSupporter) {
    return { shouldShow: false, translationCount: stats.translationCount };
  }

  // Check if dismissed until a certain count
  if (stats.translationCount <= support.dismissedUntil) {
    return { shouldShow: false, translationCount: stats.translationCount };
  }

  // Check if hit a milestone
  const hitMilestone = PROMPT_MILESTONES.find(
    (m) => stats.translationCount === m && stats.lastPromptAt < m
  );

  if (hitMilestone) {
    // Update last prompt marker
    stats.lastPromptAt = hitMilestone;
    await setUsageStats(stats);

    return {
      shouldShow: true,
      translationCount: stats.translationCount,
      milestone: hitMilestone,
    };
  }

  return { shouldShow: false, translationCount: stats.translationCount };
}

/**
 * Track a word saved event
 */
export async function trackWordSaved(): Promise<void> {
  const stats = await getUsageStats();
  stats.wordsSaved += 1;
  await setUsageStats(stats);
}

/**
 * Mark user as supporter
 */
export async function markAsSupporter(): Promise<void> {
  const status = await getSupportStatus();
  status.isSupporter = true;
  status.supportedAt = Date.now();
  await setSupportStatus(status);
}

/**
 * Dismiss prompt until next milestone
 */
export async function dismissPrompt(): Promise<void> {
  const stats = await getUsageStats();
  const support = await getSupportStatus();

  // Find next milestone
  const nextMilestone = PROMPT_MILESTONES.find((m) => m > stats.translationCount);

  if (nextMilestone) {
    support.dismissedUntil = nextMilestone - 1;
  } else {
    // No more milestones, dismiss for a long time
    support.dismissedUntil = stats.translationCount + 5000;
  }

  await setSupportStatus(support);
}

/**
 * Get current usage stats for display
 */
export async function getStats(): Promise<{
  translationCount: number;
  wordsSaved: number;
  daysUsed: number;
  isSupporter: boolean;
}> {
  const stats = await getUsageStats();
  const support = await getSupportStatus();

  const daysUsed = stats.firstUseAt
    ? Math.floor((Date.now() - stats.firstUseAt) / (1000 * 60 * 60 * 24)) + 1
    : 0;

  return {
    translationCount: stats.translationCount,
    wordsSaved: stats.wordsSaved,
    daysUsed,
    isSupporter: support.isSupporter,
  };
}

/**
 * Reset support status (for testing)
 */
export async function resetSupportStatus(): Promise<void> {
  await setSupportStatus({ ...DEFAULT_SUPPORT_STATUS });
}
