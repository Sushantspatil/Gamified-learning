import { defineConfig } from 'vite';

// Builds src/embed.js into ONE classic script (IIFE) in .embed-build/. Classic
// scripts (not ES modules) are required: modules cannot be loaded from the
// app's file:// asset origin. scripts/build-embed.mjs then wraps it in an HTML
// page together with the model.
export default defineConfig({
  publicDir: false,
  build: {
    outDir: '.embed-build',
    emptyOutDir: true,
    target: 'es2019', // older Android WebViews
    minify: 'esbuild',
    lib: {
      entry: 'src/embed.js',
      name: 'CharacterEmbedBundle',
      formats: ['iife'],
      fileName: () => 'embed.js',
    },
    rollupOptions: { output: { inlineDynamicImports: true } },
  },
});
