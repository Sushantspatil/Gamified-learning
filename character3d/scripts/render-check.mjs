// End-to-end check in a real (headless) browser: builds the app, loads the
// rigged character and verifies rendering, Idle/Walk/Run, keyboard movement,
// reloading and disposal. Screenshots go to .render-check/.
//   npm run make:model && npm run check:render
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';
import { build, preview } from 'vite';

import { CHROME_ARGS, findChrome } from './browser.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const shots = join(root, '.render-check');
mkdirSync(shots, { recursive: true });

await build({ root, logLevel: 'error' });
const server = await preview({ root, logLevel: 'error', preview: { port: 5191, strictPort: false } });
const url = server.resolvedUrls.local[0];

const browser = await puppeteer.launch({ executablePath: findChrome(), args: CHROME_ARGS, headless: true });
const problems = [];
const check = (ok, message) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${message}`);
  if (!ok) problems.push(message);
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 900, height: 700 });
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => {
    if (m.type() === 'error' || m.type() === 'warning') errors.push(`${m.type()}: ${m.text()}`);
  });

  await page.goto(`${url}?debug&model=/models/character.glb`);
  await page.waitForFunction('window.__avatar && window.__avatar.state', { timeout: 60000 });
  await sleep(800);
  await page.screenshot({ path: join(shots, '1-idle.png') });

  const ev = (fn) => page.evaluate(fn);
  check((await ev('__avatar.state')) === 'idle', 'starts in Idle');
  const clips = await ev('__avatar.animationNames');
  check(['Idle', 'Walk', 'Run'].every((n) => clips.includes(n)), `clips found: ${clips.join(', ')}`);

  // Programmatic states.
  await ev("__avatar.setState('walk')");
  await sleep(700);
  check((await ev('__avatar.state')) === 'walk', 'setState("walk")');
  await page.screenshot({ path: join(shots, '2-walk.png') });
  await ev("__avatar.setState('run')");
  await sleep(700);
  check((await ev('__avatar.state')) === 'run', 'setState("run")');
  await page.screenshot({ path: join(shots, '3-run.png') });
  await ev("__avatar.setState('idle')");
  await sleep(400);
  check((await ev('__avatar.state')) === 'idle', 'back to Idle');

  // Keyboard: W walks forward, Shift+W runs, release settles into Idle.
  await ev('document.activeElement && document.activeElement.blur()');
  const z0 = await ev('__avatar.position.z');
  const x0 = await ev('__avatar.position.x');
  await page.keyboard.down('KeyW');
  await sleep(700);
  check((await ev('__avatar.state')) === 'walk', 'holding W -> Walk');
  await page.keyboard.down('ShiftLeft');
  await sleep(900);
  check((await ev('__avatar.state')) === 'run', 'Shift+W -> Run');
  await page.screenshot({ path: join(shots, '4-keyboard-run.png') });
  await page.keyboard.up('ShiftLeft');
  await page.keyboard.up('KeyW');
  await sleep(1500);
  check((await ev('__avatar.state')) === 'idle', 'release keys -> Idle');
  const moved = Math.hypot((await ev('__avatar.position.z')) - z0, (await ev('__avatar.position.x')) - x0);
  check(moved > 1, `the character travelled (${moved.toFixed(2)} m)`);

  // Reload the model repeatedly: GPU memory must not grow.
  const mem = () => ev('({g: __avatar.renderer.info.memory.geometries, t: __avatar.renderer.info.memory.textures})');
  const before = await mem();
  for (let i = 0; i < 4; i++) await ev("__avatar.load('/models/character.glb')");
  await sleep(300);
  const after = await mem();
  check(after.g <= before.g + 1 && after.t <= before.t + 1, `no GPU leak on reload (${JSON.stringify(before)} -> ${JSON.stringify(after)})`);

  // Dispose frees everything and removes the canvas.
  await ev('__avatar.dispose()');
  await sleep(200);
  const gone = await ev("({canvas: document.querySelectorAll('#stage canvas').length, g: __avatar.renderer.info.memory.geometries, t: __avatar.renderer.info.memory.textures})");
  check(gone.canvas === 0 && gone.g === 0 && gone.t === 0, `dispose frees GPU memory (${JSON.stringify(gone)})`);

  // Missing model: a readable error, no crash.
  const bad = await browser.newPage();
  await bad.goto(`${url}?model=/models/nope.glb`);
  await bad.waitForFunction("document.querySelector('#overlay-box h2')?.textContent.includes('could not')", { timeout: 20000 });
  const message = await bad.evaluate("document.querySelector('#overlay-box').textContent");
  check(/public\/models/.test(message), 'missing model shows a helpful message');
  await bad.screenshot({ path: join(shots, '6-missing-model.png') });

  const relevant = errors.filter((e) => !/favicon|404/.test(e));
  check(relevant.length === 0, `no console errors/warnings${relevant.length ? ': ' + relevant.join(' | ') : ''}`);
} finally {
  await browser.close();
  server.httpServer.close();
}

if (problems.length) {
  console.error(`\n${problems.length} check(s) failed`);
  process.exit(1);
}
console.log('\nAll render checks passed');
