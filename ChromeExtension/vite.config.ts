import { defineConfig } from 'vite';
import { resolve } from 'path';
import { copyFileSync, mkdirSync, existsSync, readdirSync } from 'fs';

// Recursively copy directory
function copyDirSync(src: string, dest: string) {
  mkdirSync(dest, { recursive: true });
  for (const entry of readdirSync(src, { withFileTypes: true })) {
    const srcPath = resolve(src, entry.name);
    const destPath = resolve(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirSync(srcPath, destPath);
    } else {
      copyFileSync(srcPath, destPath);
    }
  }
}

// Plugin to copy static files after build
function copyStaticFiles() {
  return {
    name: 'copy-static-files',
    closeBundle() {
      const distDir = resolve(__dirname, 'dist');

      // Copy manifest.json
      copyFileSync(
        resolve(__dirname, 'manifest.json'),
        resolve(distDir, 'manifest.json')
      );

      // Copy icons if they exist
      const iconsDir = resolve(__dirname, 'icons');
      const distIconsDir = resolve(distDir, 'icons');
      if (existsSync(iconsDir)) {
        copyDirSync(iconsDir, distIconsDir);
      }

      // Copy _locales for i18n
      const localesDir = resolve(__dirname, '_locales');
      const distLocalesDir = resolve(distDir, '_locales');
      if (existsSync(localesDir)) {
        copyDirSync(localesDir, distLocalesDir);
      }
    },
  };
}

// Get build target from environment
const target = process.env.BUILD_TARGET as 'background' | 'content' | undefined;

export default defineConfig({
  build: {
    outDir: 'dist',
    emptyOutDir: target === 'background',
    rollupOptions: {
      input: target
        ? resolve(__dirname, `src/${target}.ts`)
        : {
            background: resolve(__dirname, 'src/background.ts'),
            content: resolve(__dirname, 'src/content.ts'),
          },
      output: target
        ? {
            entryFileNames: `${target}.js`,
            format: 'iife' as const,
            inlineDynamicImports: true,
          }
        : {
            entryFileNames: '[name].js',
            chunkFileNames: 'assets/[name]-[hash].js',
            format: 'es' as const,
          },
    },
    sourcemap: process.env.NODE_ENV === 'development',
  },
  plugins: [copyStaticFiles()],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },
});
