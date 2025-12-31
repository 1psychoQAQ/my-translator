/**
 * Backend Module - Cross-platform translation support
 */

export * from './types';
export { createNativeBackend } from './native-backend';
export { createWebBackend, type WebApiProvider } from './web-backend';
export {
  createBrowserStorage,
  exportWords,
  importWords,
} from './browser-storage';
export { createBackendManager, type BackendManager } from './manager';
