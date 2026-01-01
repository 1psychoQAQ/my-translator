/**
 * Support Module
 * Usage tracking and "buy me a coffee" functionality
 */

export * from './types';
export {
  trackTranslation,
  trackWordSaved,
  markAsSupporter,
  dismissPrompt,
  getStats,
  resetSupportStatus,
} from './usage-tracker';
export { showCoffeePrompt, hideCoffeePrompt } from './coffee-prompt';
