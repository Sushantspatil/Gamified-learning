// Opens the built embed page from file:// (like the app's asset origin) in
// headless Chrome and drives it the way the Flutter app does: loaded -> configure
// -> show -> ready, then the MCQ strip moves (enter, hop, exit, enter).
// Screenshots: .render-check/embed-*.png
//   npm run build:embed && node scripts/check-embed.mjs
import { mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import puppeteer from 'puppeteer-core';

import { CHROME_ARGS, findChrome } from './browser.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const page_ = resolve(root, '../assets/character3d/character.html');
const shots = join(root, '.render-check');
mkdirSync(shots, { recursive: true });
const problems = [];
const check = (ok, msg) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${msg}`);
  if (!ok) problems.push(msg);
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const browser = await puppeteer.launch({ executablePath: findChrome(), args: CHROME_ARGS, headless: true });
try {
  // ---- square card (dashboard / results) ----
  let page = await browser.newPage();
  await page.setViewport({ width: 260, height: 340, deviceScaleFactor: 2 });
  let messages = [];
  let errors = [];
  const wire = async (p) => {
    p.on('pageerror', (e) => errors.push(e.message));
    p.on('console', (m) => ['error', 'warning'].includes(m.type()) && errors.push(m.text()));
    await p.exposeFunction('__post', (m) => messages.push(m));
    await p.evaluateOnNewDocument(() => {
      window.CharacterBridge = { postMessage: (m) => window.__post(m) };
    });
  };
  const waitFor = async (text) => {
    for (let i = 0; i < 150 && !messages.includes(text); i++) await sleep(200);
    return messages.includes(text);
  };
  await wire(page);
  await page.goto(pathToFileURL(page_).href);
  check(await waitFor('loaded'), 'page reports loaded');
  check(!messages.includes('ready'), 'not shown before it is configured');
  await page.evaluate("CharacterEmbed.setState('walk'); CharacterEmbed.setFraming('full'); CharacterEmbed.show()");
  check(await waitFor('ready'), 'ready after show()');
  await page.evaluate("document.body.style.background = '#ff00ff'");
  await sleep(500);
  await page.screenshot({ path: join(shots, 'embed-walk.png') });
  // actions and cosmetics
  await page.evaluate("CharacterEmbed.setState('idle'); CharacterEmbed.setCosmetics({ avatar: 'champion', frame: 'gold' })");
  await sleep(400);
  await page.screenshot({ path: join(shots, 'embed-cosmetics.png') });
  const played = await page.evaluate("CharacterEmbed.play('nonsense')");
  check(played === false, 'an unknown action is refused, not thrown');
  await page.evaluate("window.__cheered = null; void CharacterEmbed.play('cheer').then((v) => { window.__cheered = v; })");
  await sleep(700);
  await page.screenshot({ path: join(shots, 'embed-cheer.png') });
  await sleep(1500);
  await page.screenshot({ path: join(shots, 'embed-after-cheer.png') });
  check((await page.evaluate('window.__cheered')) === true, 'a one-shot action finishes and reports it');
  await page.evaluate("void CharacterEmbed.play('think')");
  await sleep(900);
  await page.screenshot({ path: join(shots, 'embed-think.png') });
  await page.evaluate("CharacterEmbed.stopAction(); CharacterEmbed.setAmbient(true); CharacterEmbed.setAmbient(false)");
  for (const avatar of ['scholar', 'explorer', 'genius']) {
    await page.evaluate(`CharacterEmbed.setCosmetics({ avatar: '${avatar}', frame: 'silver' })`);
    await sleep(250);
    await page.screenshot({ path: join(shots, `embed-emblem-${avatar}.png`) });
  }
  await page.evaluate('CharacterEmbed.setCosmetics({})');
  await page.evaluate('CharacterEmbed.setPaused(true)');
  await page.evaluate('CharacterEmbed.setPaused(false)');
  check(errors.length === 0, `card: no page errors${errors.length ? ': ' + errors.join(' | ') : ''}`);
  await page.close();

  // ---- wide strip (MCQ): enter from the left, hop, exit right, enter again ----
  page = await browser.newPage();
  await page.setViewport({ width: 360, height: 150, deviceScaleFactor: 2 });
  messages = [];
  errors = [];
  await wire(page);
  await page.goto(pathToFileURL(page_).href);
  await waitFor('loaded');
  await page.evaluate("CharacterEmbed.setState('idle'); CharacterEmbed.setFraming('strip'); CharacterEmbed.enter(2500, true); CharacterEmbed.show()");
  await waitFor('ready');
  await page.evaluate("document.body.style.background = '#1b2140'");
  const shotsAt = [300, 900, 1500, 2300];
  let last = 0;
  for (const t of shotsAt) {
    await sleep(t - last);
    last = t;
    await page.screenshot({ path: join(shots, `strip-enter-${t}.png`) });
  }
  await sleep(1800); // arrived and settled
  await page.screenshot({ path: join(shots, 'strip-rest.png') });
  await page.evaluate('CharacterEmbed.hop()');
  await sleep(250);
  await page.screenshot({ path: join(shots, 'strip-hop.png') });
  await sleep(500);
  await page.evaluate('CharacterEmbed.exit(750)');
  await sleep(380);
  await page.screenshot({ path: join(shots, 'strip-exit.png') });
  await sleep(700);
  await page.evaluate('CharacterEmbed.enter(3000)');
  await sleep(700);
  await page.screenshot({ path: join(shots, 'strip-enter-again.png') });
  check(errors.length === 0, `strip: no page errors${errors.length ? ': ' + errors.join(' | ') : ''}`);
} finally {
  await browser.close();
}
if (problems.length) process.exit(1);
console.log('Embed page OK');
