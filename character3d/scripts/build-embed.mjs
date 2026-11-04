// Builds the single-file page the Flutter app shows in a WebView:
//   <repo>/assets/character3d/character.html  (script + character.glb as base64)
//   npm run build:embed [model.glb]
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'vite';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const model = resolve(root, process.argv[2] ?? 'public/models/character.glb');
const out = resolve(root, '../assets/character3d/character.html');

await build({ root, configFile: join(root, 'vite.embed.config.js'), logLevel: 'error' });

const script = readFileSync(join(root, '.embed-build/embed.js'), 'utf8').replace(/<\/script/gi, '<\\/script');
const glb = readFileSync(model).toString('base64');

const html = `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
  html, body { margin: 0; height: 100%; background: transparent; overflow: hidden; }
  #stage { position: fixed; inset: 0; }
  canvas { touch-action: none; }
</style>
</head>
<body>
<div id="stage"></div>
<script>window.__CHARACTER_GLB_B64 = "${glb}";</script>
<script>${script}</script>
</body>
</html>
`;
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, html);
console.log(`wrote ${out} (${(html.length / 1048576).toFixed(1)} MB)`);
