// Shared helpers for the scripts that need a real (headless) browser.
import { existsSync } from 'node:fs';

const CANDIDATES = [
  process.env.CHROME_PATH,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
];

export function findChrome() {
  const found = CANDIDATES.find((path) => path && existsSync(path));
  if (!found) {
    throw new Error('Chrome/Edge not found. Set CHROME_PATH to the browser executable.');
  }
  return found;
}

/** Flags that give headless Chrome a software WebGL so no GPU is needed. */
export const CHROME_ARGS = [
  '--no-sandbox',
  '--use-angle=swiftshader',
  '--enable-unsafe-swiftshader',
  '--ignore-gpu-blocklist',
  '--autoplay-policy=no-user-gesture-required',
];
