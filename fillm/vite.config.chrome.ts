import { defineConfig } from 'vite';
import { resolve } from 'path';
import { copyFileSync, mkdirSync, existsSync, readdirSync, statSync, cpSync } from 'fs';

// Plugin to copy static files after build
function copyStaticFiles() {
  return {
    name: 'copy-static-files',
    closeBundle() {
      const outDir = 'dist/chrome';

      // Copy manifest.json
      copyFileSync(
        resolve(__dirname, 'src/chrome/manifest.json'),
        resolve(__dirname, outDir, 'manifest.json')
      );

      // Copy popup files
      copyFileSync(
        resolve(__dirname, 'src/ui/popup/popup.html'),
        resolve(__dirname, outDir, 'popup.html')
      );
      copyFileSync(
        resolve(__dirname, 'src/ui/popup/popup.css'),
        resolve(__dirname, outDir, 'popup.css')
      );

      // Copy icons directory
      const iconsDir = resolve(__dirname, 'src/chrome/public/icons');
      const outIconsDir = resolve(__dirname, outDir, 'icons');
      if (existsSync(iconsDir)) {
        mkdirSync(outIconsDir, { recursive: true });
        const files = readdirSync(iconsDir);
        for (const file of files) {
          const srcPath = resolve(iconsDir, file);
          if (statSync(srcPath).isFile()) {
            copyFileSync(srcPath, resolve(outIconsDir, file));
          }
        }
      }

      console.log('Static files copied to', outDir);
    },
  };
}

export default defineConfig({
  build: {
    outDir: 'dist/chrome',
    emptyOutDir: true,
    rollupOptions: {
      input: {
        background: resolve(__dirname, 'src/chrome/background.ts'),
        content: resolve(__dirname, 'src/chrome/content.ts'),
        popup: resolve(__dirname, 'src/ui/popup/popup.ts'),
      },
      output: {
        entryFileNames: '[name].js',
        chunkFileNames: 'chunks/[name].js',
        assetFileNames: 'assets/[name].[ext]',
        format: 'es',
      },
    },
    sourcemap: process.env.NODE_ENV === 'development',
    minify: 'terser',
    target: 'esnext',
  },
  resolve: {
    alias: {
      '@core': resolve(__dirname, 'src/core'),
      '@ui': resolve(__dirname, 'src/ui'),
    },
  },
  plugins: [copyStaticFiles()],
});
