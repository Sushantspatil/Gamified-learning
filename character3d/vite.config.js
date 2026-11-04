import { defineConfig } from 'vite';

// `public/` is served from the site root, so public/models/character.glb is
// available at /models/character.glb. Change `base` if the app is hosted in a
// sub-folder (e.g. base: '/avatar/') and pass modelUrl accordingly.
export default defineConfig({
  base: './',
  server: { host: '127.0.0.1', port: 5173 },
  build: {
    target: 'es2022',
    chunkSizeWarningLimit: 900, // three.js is large by nature
  },
});
