// Rigs a static character mesh: skeleton + skin weights + Idle/Walk/Run clips.
//   node scripts/rig/rig-model.mjs [input.glb] [output.glb] [textureSize]
// Defaults: public/models/meshy-model.glb -> public/models/character.glb, 2048 px.
import { mkdirSync, writeFileSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';
import { createServer } from 'vite';

import { CHROME_ARGS, findChrome } from '../browser.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '../..');
const input = process.argv[2] ?? 'public/models/meshy-model.glb';
const output = resolve(root, process.argv[3] ?? 'public/models/character.glb');
const texture = process.argv[4] ?? '2048';

const server = await createServer({ root, logLevel: 'error', server: { port: 5196, strictPort: false } });
await server.listen();
const browser = await puppeteer.launch({ executablePath: findChrome(), args: CHROME_ARGS, headless: true });
try {
  const page = await browser.newPage();
  page.on('pageerror', (e) => console.error('page error:', e.message));
  page.on('console', (m) => ['error', 'warning'].includes(m.type()) && !/404/.test(m.text()) && console.error(m.text()));
  const model = '/' + input.replace(/^public\//, '');
  await page.goto(`${server.resolvedUrls.local[0]}scripts/rig/rig-model.html?model=${model}&tex=${texture}`);
  await page.waitForFunction('window.__done', { timeout: 300000 });
  const bytes = Buffer.from(await page.evaluate('window.__glb'), 'base64');
  mkdirSync(dirname(output), { recursive: true });
  writeFileSync(output, bytes);
  console.log(`rigged ${basename(input)} -> ${output} (${(bytes.length / 1048576).toFixed(1)} MB)`);
} finally {
  await browser.close();
  await server.close();
}
