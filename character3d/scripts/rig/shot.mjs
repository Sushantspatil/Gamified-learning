// node scripts/rig/shot.mjs <page.html?query> <out.png> [width height]
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';
import { createServer } from 'vite';
import { CHROME_ARGS, findChrome } from '../browser.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '../..');
const [page_, out, w = '900', h = '1000'] = process.argv.slice(2);
const server = await createServer({ root, logLevel: 'error', server: { port: 5195, strictPort: false } });
await server.listen();
const browser = await puppeteer.launch({ executablePath: findChrome(), args: CHROME_ARGS, headless: true });
try {
  const page = await browser.newPage();
  await page.setViewport({ width: Number(w), height: Number(h) });
  page.on('pageerror', (e) => console.error('pageerror', e.message));
  page.on('console', (m) => ['error', 'warning'].includes(m.type()) && !/404/.test(m.text()) && console.error(m.text()));
  await page.goto(`${server.resolvedUrls.local[0]}${page_}`);
  await page.waitForFunction('window.__done', { timeout: 120000 });
  console.log(JSON.stringify(await page.evaluate('window.__info ?? null')));
  await page.screenshot({ path: out });
} finally {
  await browser.close();
  await server.close();
}
