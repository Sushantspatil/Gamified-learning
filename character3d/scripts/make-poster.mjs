// Renders a still image of the character (front view, relaxed pose, transparent
// background) from the built embed page: assets/character3d/poster.png. The app
// shows it while the live 3D view loads, so there is never a jump from an icon.
//   npm run build:embed && node scripts/make-poster.mjs
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import puppeteer from 'puppeteer-core';

import { CHROME_ARGS, findChrome } from './browser.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const page_ = resolve(root, '../assets/character3d/character.html');
const out = resolve(root, '../assets/character3d/poster.png');

const browser = await puppeteer.launch({ executablePath: findChrome(), args: CHROME_ARGS, headless: true });
try {
  const page = await browser.newPage();
  await page.setViewport({ width: 240, height: 300, deviceScaleFactor: 2 });
  const messages = [];
  await page.exposeFunction('__post', (m) => messages.push(m));
  await page.evaluateOnNewDocument(() => {
    window.CharacterBridge = { postMessage: (m) => window.__post(m) };
  });
  await page.goto(pathToFileURL(page_).href);
  for (let i = 0; i < 150 && !messages.includes('loaded'); i++) await new Promise((r) => setTimeout(r, 200));
  await page.evaluate("CharacterEmbed.setState('idle'); CharacterEmbed.setFraming('full'); CharacterEmbed.show()");
  await new Promise((r) => setTimeout(r, 900));
  await page.screenshot({ path: out, omitBackground: true });
  console.log(`wrote ${out}`);
} finally {
  await browser.close();
}
