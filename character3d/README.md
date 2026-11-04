# SkillVerse 3D Avatar (Three.js)

A 3D character viewer for a rigged `.glb`: studio lighting, soft ground shadow,
neon glow, orbit camera, and **walking** (plus Idle and Run if you have them)
with smooth cross-fades and WASD controls. No speech or lip-sync.

Standard Three.js, modular ES modules, built with Vite. This is **web code**:
it does not run inside the Flutter app by itself (see the last section).

## Run it (the character already walks)

`public/models/meshy-model.glb` is your original Meshy mesh (static). It was
rigged here into `public/models/character.glb`: a 17-bone humanoid skeleton,
skin weights, and looping **Idle**, **Walk** and **Run** animations, with the
textures shrunk (27 MB -> 2.6 MB).

```bash
cd character3d
npm install       # first time only
npm run dev       # http://127.0.0.1:5173  (loads /models/character.glb)
```

The character starts in Idle. Use **W A S D** (or arrows) to walk around,
**Shift** to run, drag to orbit, scroll to zoom, or press the Idle / Walk / Run
buttons.

### How the rig was made, and how to redo it

```bash
npm run rig                      # meshy-model.glb -> character.glb
node scripts/rig/rig-model.mjs public/models/in.glb public/models/out.glb 1024
```

`scripts/rig/rig-model.js` builds the skeleton from joint landmarks (fractions
of the character's height, measured on this model), computes skin weights from
distance to each bone (limbs only move their own side, weights are smoothed
across the mesh), generates the three gaits, and exports a single .glb in a
headless browser. Check the result by eye with a contact sheet:

```bash
node scripts/rig/shot.mjs "scripts/rig/preview.html?clip=Walk" .render-check/walk.png 1500 900
```

To rig a different character, replace the numbers in `JOINTS` (use
`scripts/rig/analyze.html?view=front|side` to read them off a measured grid).
This is an automatic rig: it suits stylized characters. Loose clothing, hair or
a cape may stretch a little; a hand-weighted rig from a 3D artist (or Meshy's
own rigging, if you get access to it) will always look better.

### Limits of this rig

- No face or finger animation; hands and head move as one piece each.
- Walk/Run were authored for 1.3 / 3.3 m/s (`DEFAULT_SPEEDS`), so feet match the
  ground when the avatar moves at those speeds.

### Using a Meshy rigged file instead

If you later get a rigged .glb from Meshy, put it in `public/models/` and open
`?model=/models/your-file.glb`. A file with a single animation is used as the
walk cycle. Separate Idle/Run files can be added with
`?idle=/models/idle.glb&walk=/models/walk.glb&run=/models/run.glb`
(same bone names required). Animations that move the hips forward are
flattened (`inPlaceAnimations`).

Check what a file contains:

```bash
node scripts/inspect-glb.mjs public/models/your-file.glb
```

## Use it in your own page

```js
import { CharacterAvatar } from './src/CharacterAvatar.js';

const avatar = await CharacterAvatar.create(document.querySelector('#stage'), {
  modelUrl: '/models/character-walk.glb',
});

avatar.setState('walk');        // 'idle' | 'walk' | 'run' (animates in place)
avatar.setSpeed(2.4);           // or choose the state from a speed in m/s
avatar.frameCharacter('bust');  // 'full' | 'bust' | 'face'
avatar.dispose();               // always, on unmount
```

`#stage` needs a size (e.g. `position: fixed; inset: 0`). The canvas fills it
and follows resizes. In React, create it in an effect and call `dispose()` in
the cleanup (create is async, so ignore a result that arrives after cleanup).

| Call | What it does |
| --- | --- |
| `CharacterAvatar.create(container, options)` | Creates the scene and loads the model. |
| `new CharacterAvatar(...)` + `load(url?)` | Same in two steps (`on('progress')` for a loader bar). `load` again swaps the model and frees the old one. |
| `setState(state)` | Cross-fades (0.25 s) to Idle, Walk or Run. Walk and Run keep the stride phase. |
| `setSpeed(mps)` | Picks the state from a speed (with hysteresis) and matches the playback rate. |
| `frameCharacter(framing)` | Re-frames the camera. |
| `setKeyboardEnabled(bool)` | WASD / arrows on or off (ignored while typing in inputs). |
| `on(event, fn)` | `progress`, `loaded`, `statechange`, `error`. Returns an unsubscribe function. |
| `dispose()` | Stops the loop and frees all GPU memory, listeners and the canvas. |

Options: `modelUrl`, `animationUrls`, `inPlaceAnimations` (true),
`targetHeight` (1.75 m), `background` (colour or `null` for transparent, which
turns bloom off), `fadeDuration` (0.25), `walkSpeed` / `runSpeed` (1.3 / 3.3),
`keyboard` (true), `moveRadius` (10), `glowIntensity`, `bloom`,
`bloomStrength`, `dracoDecoderPath`, `maxPixelRatio` (2).

A material with an emissive colour, or named `neon`, `glow`, `emissive` or
`led`, gets the glow. The model should face +Z with feet near y = 0; any scale
is resized to `targetHeight`.

## Files

```
src/CharacterAvatar.js        scene, lights, shadows, camera, loop, loading, dispose
src/LocomotionController.js   Idle/Walk/Run state machine and cross-fades
src/locomotionLogic.js        pure rules (thresholds, hysteresis, playback rate)
src/InputController.js        WASD / arrows / Shift
src/dispose.js, emitter.js    cleanup helpers, tiny event emitter
src/main.js, index.html       the demo page
scripts/                      inspect-glb, make-test-model, render-check
```

## Tests

```bash
npm test               # states, hysteresis, clip selection (incl. a single clip)
npm run make:model     # builds public/models/test-character.glb, a stand-in rig
npm run rig            # re-rigs meshy-model.glb into character.glb
npm run check:render   # headless Chrome: render, Idle/Walk/Run, keyboard travel,
                       #   reload leaks, dispose, missing-file message
```

`test-character.glb` is a generated placeholder with Idle/Walk/Run so the viewer
can be tried; it is not your character. `check:render` uses a software renderer
(behaviour, not frame rate) and saves screenshots to `.render-check/`; set
`CHROME_PATH` if no browser is found.

## Troubleshooting

- **"Could not load the character model"**: wrong path; the file must be in
  `public/models/`.
- **Character stands still / T-pose**: the file has no animation (a plain Meshy
  export). Download the rigged walking version.
- **Walks off while animating in place**: set `inPlaceAnimations: true` (default).

## In the Flutter app

The app shows this character in a transparent WebView (`webview_flutter`):

- **Dashboard**: a welcome card with the character walking
  (`lib/features/dashboard/presentation/widgets/mascot_card.dart`).
- **MCQ play**: a wide strip between the question and the options. The
  character walks in from the left edge for each question, hops when an option
  is picked, and runs off to the right when the answer is submitted. If 3D
  cannot run, the older 2D host is shown there instead
  (`_CharacterSlot` in `mcq_question_view.dart`, `Character3dController`).
- **Results**: at the top of the MCQ / Sudden Death, Sort It Out and Match the
  Following result cards. It walks after a good game and stands after a bad
  one (`lib/features/character3d/presentation/result_mascot.dart`).

How it works: `npm run build:embed` bundles `src/embed.js`, the avatar code and
`public/models/character.glb` into ONE page,
`../assets/character3d/character.html` (about 4 MB, works offline).
`Character3dView` loads it as a Flutter asset, waits for the page to say
`ready`, and switches animation with `CharacterEmbed.setState(...)`. Until
then, and whenever the WebView is unavailable (unsupported platform, error,
25 s timeout), the screen shows its normal fallback (the old trophy icon /
a game icon), so nothing depends on 3D.

The view ignores touches, and stops drawing while another screen covers it or
the app is in the background.

After changing the model or the avatar code, rebuild and commit the asset:

```bash
npm run rig            # only if the mesh or the rig changed
npm run build:embed
node scripts/check-embed.mjs   # opens the page from file:// in headless Chrome
```

Not verified here: this has not been run on a real phone (no device or
emulator available). The page itself was tested in Chrome from a file:// URL
with the same bridge messages.
