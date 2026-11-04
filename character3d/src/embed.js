// Entry point for the copy of the avatar that runs inside the Flutter app's
// WebView. It is bundled into ONE html file (see scripts/build-embed.mjs): the
// model is embedded as base64 in `window.__CHARACTER_GLB_B64`, so nothing is
// fetched from the network or the file system.
//
// Flutter drives it through `window.CharacterEmbed`:
//   setState('idle' | 'walk' | 'run')        loop to play
//   setFraming('full' | 'bust' | 'face' | 'strip')
//   setPaused(true | false)                  stop / resume drawing
//   setCosmetics({ avatar, frame })          equipped items (see cosmetics.js)
//   setStyle({ dark, accent })               theme-aware lighting and sparkle colour
//   sparkle()                                a burst of sparkles above the character
//   setAmbient(true | false)                 now and then a small idle gesture
//   play('wave' | 'cheer' | 'sad' | 'think' | 'clap' | 'lookaround')
//   stopAction()
//   show()                                   reveal the canvas (replies 'ready')
//   enter(ms, thenThink)  walk in from the left edge to the centre ('strip' framing)
//   hop()      jump on the spot
//   exit(ms)   run off the right edge (the next enter() waits for it)
// and hears back through the `CharacterBridge` JavaScript channel:
//   'loaded'  the model is loaded; configure it, then call show()
//   'ready'   the character is on screen
//   'error:<message>'
import { CharacterAvatar } from './CharacterAvatar.js';

const stage = document.getElementById('stage');
const params = new URLSearchParams(location.search);
const send = (message) => {
  try {
    window.CharacterBridge?.postMessage(message);
  } catch {
    /* running outside the app (e.g. in a desktop browser) */
  }
};

/** Where the character stops after walking in: 0 = centre, 1 = right edge. */
const REST_AT = 0; // the centre of the strip
/** How far past the edge it starts / ends, so it is fully out of sight (metres). */
const OFF_SCREEN = 0.6;
/** Small gestures an idle character makes now and then, with how often. */
const AMBIENT = [
  ['lookaround', 3],
  ['wave', 1],
];

let avatar = null;
let exiting = Promise.resolve();
let paused = false;
let ambientTimer = null;
let pendingState = params.get('state') ?? 'walk';
let pendingFraming = params.get('framing') ?? 'full';

function scheduleAmbient() {
  clearTimeout(ambientTimer);
  ambientTimer = setTimeout(() => {
    const busy = !avatar || paused || avatar.acting || avatar.state !== 'idle';
    if (!busy) {
      const total = AMBIENT.reduce((n, [, weight]) => n + weight, 0);
      let pick = Math.random() * total;
      for (const [name, weight] of AMBIENT) {
        pick -= weight;
        if (pick <= 0) {
          avatar.playAction(name);
          break;
        }
      }
    }
    scheduleAmbient();
  }, 6000 + Math.random() * 5000);
}

window.CharacterEmbed = {
  setState(state) {
    pendingState = state;
    if (avatar) avatar.setState(state);
  },
  setFraming(framing) {
    pendingFraming = framing;
    if (avatar) avatar.frameCharacter(framing);
  },
  setPaused(value) {
    paused = value;
    if (!avatar) return;
    value ? avatar.pause() : avatar.resume();
  },
  setCosmetics(items) {
    avatar?.setCosmetics(items ?? {});
  },
  setStyle(style) {
    avatar?.setStyle(style ?? {});
  },
  sparkle() {
    avatar?.sparkle();
  },
  setAmbient(on) {
    clearTimeout(ambientTimer);
    if (on) scheduleAmbient();
  },
  play(name) {
    return avatar ? avatar.playAction(name) : Promise.resolve(false);
  },
  stopAction() {
    avatar?.stopAction();
  },
  show() {
    stage.style.visibility = 'visible';
    send('ready');
  },
  async enter(ms, thenThink = false) {
    await exiting; // let the previous run-off finish first
    if (!avatar) return;
    const half = avatar.visibleHalfWidth();
    await avatar.travel({ fromX: -(half + OFF_SCREEN), toX: half * REST_AT, duration: ms / 1000 });
    // Waiting for the answer: hand to chin (ends by itself when it moves again).
    if (thenThink && avatar && !avatar.acting) avatar.playAction('think');
  },
  hop() {
    avatar?.hop();
  },
  exit(ms) {
    if (!avatar) return;
    const half = avatar.visibleHalfWidth();
    exiting = avatar.travel({ toX: half + OFF_SCREEN, duration: ms / 1000, endYaw: 0 });
  },
};

async function start() {
  const b64 = window.__CHARACTER_GLB_B64;
  if (!b64) throw new Error('model data is missing from the page');
  stage.style.visibility = 'hidden'; // until Flutter has configured it
  avatar = new CharacterAvatar(stage, {
    modelUrl: `data:model/gltf-binary;base64,${b64}`,
    background: null, // transparent: the app's card shows through
    bloom: false,
    keyboard: false,
    interactive: false,
    shadowMapSize: 1024,
    maxPixelRatio: 2,
  });
  await avatar.load();
  avatar.setState(pendingState);
  avatar.frameCharacter(pendingFraming);
  window.__CHARACTER_GLB_B64 = null; // free the base64 copy
  send('loaded');
}

start().catch((error) => {
  console.error(error);
  send(`error:${error?.message ?? error}`);
});

window.addEventListener('pagehide', () => {
  clearTimeout(ambientTimer);
  avatar?.dispose();
});
