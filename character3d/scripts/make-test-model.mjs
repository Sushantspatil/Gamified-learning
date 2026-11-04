// Builds public/models/test-character.glb: a stand-in rig with Idle/Walk/Run
// clips and jawOpen/viseme_*/eyeBlink* blendshapes, exported in a real browser.
//   npm run make:model
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';
import { createServer } from 'vite';

import { CHROME_ARGS, findChrome } from './browser.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'public/models/test-character.glb');

const server = await createServer({ root, logLevel: 'error', server: { port: 5190, strictPort: false } });
await server.listen();
const url = server.resolvedUrls.local[0];

const browser = await puppeteer.launch({ executablePath: findChrome(), args: CHROME_ARGS, headless: true });
try {
  const page = await browser.newPage();
  page.on('pageerror', (error) => console.error('page error:', error.message));
  page.on('console', (m) => m.type() === 'error' && console.error('console:', m.text()));
  await page.goto(`${url}scripts/model-builder.html`);
  await page.waitForFunction('window.__glb', { timeout: 60000 });
  const base64 = await page.evaluate('window.__glb');
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, Buffer.from(base64, 'base64'));
  console.log(`wrote ${out} (${(Buffer.from(base64, 'base64').length / 1024).toFixed(0)} KB)`);
} finally {
  await browser.close();
  await server.close();
}
