/**
 * Support/Donation Types
 */

export interface UsageStats {
  /** Total translations count */
  translationCount: number;
  /** Total words saved */
  wordsSaved: number;
  /** First use timestamp */
  firstUseAt: number;
  /** Last prompt shown at count */
  lastPromptAt: number;
}

export interface SupportStatus {
  /** User has supported (bought coffee) */
  isSupporter: boolean;
  /** Support timestamp */
  supportedAt?: number;
  /** Prompt dismissed until this count */
  dismissedUntil: number;
}

export interface CoffeePromptTrigger {
  shouldShow: boolean;
  translationCount: number;
  milestone?: number;
}

// Milestones to trigger prompt
export const PROMPT_MILESTONES = [500, 1000, 2000, 5000];

// Storage keys
export const USAGE_STATS_KEY = 'translator_usage_stats';
export const SUPPORT_STATUS_KEY = 'translator_support_status';

// Payment links (update with your actual links)
export const PAYMENT_LINKS = {
  // 爱发电
  afdian: 'https://afdian.com/a/your-username',
  // 微信赞赏码图片 (base64 or URL)
  wechatQR: '',
  // 支付宝收款码图片
  alipayQR: '',
  // Buy Me a Coffee (国际用户)
  buymeacoffee: 'https://buymeacoffee.com/your-username',
  // GitHub Sponsors
  github: 'https://github.com/sponsors/your-username',
};
