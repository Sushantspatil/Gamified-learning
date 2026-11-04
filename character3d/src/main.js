// Demo page. Extra clips: ?idle=/models/idle.glb&walk=/models/walk.glb&run=/models/run.glb
// The reusable part is CharacterAvatar; this file only wires the
// buttons. Query parameters:  ?model=/models/other.glb   ?debug (exposes window.__avatar)
import { CharacterAvatar } from './CharacterAvatar.js';

const params = new URLSearchParams(location.search);
const modelUrl = params.get('model') ?? '/models/character.glb';

const $ = (selector) => document.querySelector(selector);
const overlay = $('#overlay');
const status = $('#status');
const stateButtons = [...document.querySelectorAll('[data-state]')];

let avatar = null;

function setStatus(text) {
  status.textContent = text;
}

function showError(error) {
  overlay.hidden = false;
  $('#overlay-box').innerHTML = '';
  const h = document.createElement('h2');
  h.textContent = 'The avatar could not be loaded';
  const p = document.createElement('p');
  p.textContent = error.message; // textContent: never render HTML from errors
  const tip = document.createElement('p');
  tip.innerHTML =
    'Put your exported file at <code>public/models/character.glb</code> ' +
    '(see README.md), or open this page with <code>?model=/models/your-file.glb</code>.';
  $('#overlay-box').append(h, p, tip);
}

function refreshStateButtons() {
  for (const button of stateButtons) {
    button.setAttribute('aria-pressed', String(button.dataset.state === avatar.state));
  }
}

async function main() {
  const progress = $('#progress');
  try {
    const animationUrls = Object.fromEntries(
      ['idle', 'walk', 'run'].filter((k) => params.get(k)).map((k) => [k, params.get(k)]),
    );
    avatar = new CharacterAvatar($('#stage'), { modelUrl, animationUrls });
    avatar.on('progress', (value) => (progress.value = value));
    await avatar.load();
  } catch (error) {
    console.error(error);
    avatar?.dispose();
    avatar = null;
    showError(error);
    return;
  }

  overlay.hidden = true;
  $('#panel').hidden = false;
  $('#hint').hidden = false;
  refreshStateButtons();
  setStatus(`Clips: ${avatar.animationNames.join(', ') || 'none'}`);

  avatar.on('statechange', ({ to }) => {
    refreshStateButtons();
    setStatus(`State: ${to}`);
  });
  avatar.on('error', (error) => setStatus(error.message));

  for (const button of stateButtons) {
    button.addEventListener('click', () => avatar.setState(button.dataset.state));
  }

  for (const button of document.querySelectorAll('[data-frame]')) {
    button.addEventListener('click', () => avatar.frameCharacter(button.dataset.frame));
  }

  const keys = $('#toggle-keys');
  keys.addEventListener('click', () => {
    const on = keys.getAttribute('aria-pressed') !== 'true';
    keys.setAttribute('aria-pressed', String(on));
    keys.textContent = `Keyboard: ${on ? 'on' : 'off'}`;
    avatar.setKeyboardEnabled(on);
  });

  if (params.has('debug')) window.__avatar = avatar;
}

main();

// Hot reload and page teardown: free the GPU and the audio context.
const cleanup = () => avatar?.dispose();
window.addEventListener('pagehide', cleanup);
import.meta.hot?.dispose(cleanup);
