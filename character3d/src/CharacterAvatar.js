import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';

import { InputController } from './InputController.js';
import { LocomotionController } from './LocomotionController.js';
import { Emitter } from './emitter.js';
import { disposeObject3D, disposeTexture } from './dispose.js';
import { createEmblem, createFrameRing } from './cosmetics.js';
import { Sparkles } from './sparkles.js';
import {
  DEFAULT_SPEEDS,
  LocomotionState,
  nominalSpeed,
  shortestAngle,
} from './locomotionLogic.js';

const DEFAULT_OPTIONS = {
  /** Where the GLB is served from. */
  modelUrl: '/models/character.glb',
  /** The model is scaled so it stands this tall (metres). */
  targetHeight: 1.75,
  /** Scene background colour, or null for a transparent canvas (no bloom). */
  background: 0x10142a,
  /** Cross-fade length between Idle / Walk / Run, seconds. */
  fadeDuration: 0.25,
  /** Speeds (m/s) the Walk and Run clips were authored for. */
  ...DEFAULT_SPEEDS,
  /** WASD / arrow keys move the character and pick Idle / Walk / Run. */
  keyboard: true,
  /** The character cannot leave a circle of this radius (metres). */
  moveRadius: 10,
  /** Emissive boost for "neon" materials, and the bloom that makes them glow. */
  glowIntensity: 1.8,
  bloom: true,
  bloomStrength: 0.35,
  /** Optional Draco decoder folder, only needed for Draco-compressed GLBs. */
  dracoDecoderPath: null,
  /**
   * Clips kept in separate .glb files, e.g. { idle: '/models/idle.glb',
   * walk: '/models/walk.glb', run: '/models/run.glb' }. They must use the same
   * skeleton (bone names) as the character.
   */
  animationUrls: null,
  /** Remove sideways/forward travel baked into clips, so the character does not slide away and snap back each loop. */
  inPlaceAnimations: true,
  /** Cap the pixel ratio; 2 keeps phones fast. */
  maxPixelRatio: 2,
  /** Shadow resolution; 1024 is plenty (and lighter) on phones. */
  shadowMapSize: 2048,
  /** false = the camera is fixed (no orbit/zoom), e.g. when embedded in an app. */
  interactive: true,
};

/** Camera framings: `focus` = height of the look-at point, `half` = half the visible height (both x model height). */
const FRAMINGS = {
  full: { focus: 0.54, half: 0.68 },
  bust: { focus: 0.8, half: 0.24 },
  face: { focus: 0.92, half: 0.12 },
  // A wide, short banner seen front-on; the character travels along it, so the
  // camera stays fixed on the centre line instead of following.
  strip: { focus: 0.54, half: 0.64, dir: [0, 0.05, 1], fixed: true },
};

/**
 * A stylized 3D avatar in a studio scene.
 *
 *   const avatar = await CharacterAvatar.create(container, { modelUrl });
 *   avatar.setState('walk');          // 'idle' | 'walk' | 'run'
 *   avatar.dispose();                 // on unmount
 *
 * Events (avatar.on): 'progress', 'loaded', 'statechange', 'error'.
 */
export class CharacterAvatar extends Emitter {
  static async create(container, options = {}) {
    const avatar = new CharacterAvatar(container, options);
    try {
      await avatar.load();
    } catch (error) {
      avatar.dispose();
      throw error;
    }
    return avatar;
  }

  // ---- state -------------------------------------------------------------
  #disposed = false;
  #lastTime = 0;
  #speed = 0; // current ground speed, m/s
  #manualState = null; // set by setState(); cleared when keys are used
  #yaw = 0;
  #framing = 'full';
  #path = null; // scripted walk along x, see travel()
  #hop = null; // scripted jump, see hop()
  #twirl = null; // scripted spin on the spot, see twirl()
  #settleYaw = null; // where to turn to after a scripted walk
  #modelHeight = 1.75;
  #resizeObserver = null;
  #loadToken = 0;

  // ---- three objects -----------------------------------------------------
  #renderer;
  #scene = new THREE.Scene();
  #camera;
  #controls;
  #composer = null;
  #bloom = null;
  #root = new THREE.Group(); // moves and turns; the model hangs under it
  #model = null;
  #mixer = null;
  #env = null;
  #keyLight;
  #ground;
  #blob;
  #blobTexture;
  #glowMaterials = [];
  #rimA; // back light, left (cool / accent)
  #rimB; // back light, right (warm)
  #fill; // sky/ground bounce
  #sparkles = null;
  #lastActing = null;
  #burstTimer = 0;
  #ring = null; // floor ring for the equipped frame
  #emblem = null; // floating emblem for the equipped avatar
  #clock = 0;

  // ---- controllers -------------------------------------------------------
  #loco = null;
  #input = null;

  constructor(container, options = {}) {
    super();
    this.container = container;
    this.options = { ...DEFAULT_OPTIONS, ...options };

    const o = this.options;
    const renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: o.background === null,
      powerPreference: 'high-performance',
    });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, o.maxPixelRatio));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.05;
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.domElement.style.cssText = 'display:block;width:100%;height:100%;outline:none';
    renderer.domElement.tabIndex = 0;
    container.appendChild(renderer.domElement);
    this.#renderer = renderer;

    this.#camera = new THREE.PerspectiveCamera(35, 1, 0.05, 100);
    this.#scene.add(this.#root);
    if (o.background !== null) this.#scene.background = new THREE.Color(o.background);

    this.#buildLights();
    this.#buildGround();

    this.#controls = new OrbitControls(this.#camera, renderer.domElement);
    this.#controls.enableDamping = true;
    this.#controls.dampingFactor = 0.08;
    this.#controls.enablePan = false;
    this.#controls.enabled = o.interactive;
    this.#controls.minDistance = 1.2;
    this.#controls.maxDistance = 7;
    this.#controls.minPolarAngle = THREE.MathUtils.degToRad(25);
    this.#controls.maxPolarAngle = THREE.MathUtils.degToRad(88); // never below the floor

    // Bloom only makes sense with an opaque background (alpha is lost in the
    // post-processing chain), so it turns itself off for transparent canvases.
    if (o.bloom && o.background !== null) this.#buildComposer();

    this.#onContextLost = (event) => {
      event.preventDefault(); // allow the browser to restore the context
      renderer.setAnimationLoop(null);
    };
    this.#onContextRestored = () => this.#startLoop();
    renderer.domElement.addEventListener('webglcontextlost', this.#onContextLost);
    renderer.domElement.addEventListener('webglcontextrestored', this.#onContextRestored);

    this.#resizeObserver = new ResizeObserver(() => this.resize());
    this.#resizeObserver.observe(container);
    this.resize();

    if (o.keyboard) this.#input = new InputController(window);
    this.#startLoop();
  }

  #onContextLost;
  #onContextRestored;

  // ---- public API --------------------------------------------------------

  get state() {
    return this.#loco?.state ?? null;
  }

  get animationNames() {
    return this.#loco?.clipNames ?? [];
  }

  get camera() {
    return this.#camera;
  }

  get position() {
    return this.#root.position;
  }

  get renderer() {
    return this.#renderer;
  }

  /**
   * Loads a GLB (replacing the current model). Rejects with a readable error
   * when the file is missing or invalid.
   */
  async load(url = this.options.modelUrl) {
    this.#assertAlive();
    const token = ++this.#loadToken;

    const loader = new GLTFLoader();
    loader.setMeshoptDecoder(MeshoptDecoder);
    let draco = null;
    if (this.options.dracoDecoderPath) {
      draco = new DRACOLoader().setDecoderPath(this.options.dracoDecoderPath);
      loader.setDRACOLoader(draco);
    }

    let gltf;
    let extraClips = [];
    try {
      gltf = await loader.loadAsync(url, (event) => {
        if (event.lengthComputable) this.emit('progress', event.loaded / event.total);
      });
      extraClips = await this.#loadExternalClips(loader);
    } catch (cause) {
      const error = new Error(
        `Could not load the character model at "${url}". ` +
          'Check the path (is the file in public/models/?) and that it is a valid .glb. ' +
          `(${cause?.message ?? cause})`,
      );
      error.cause = cause;
      this.emit('error', error);
      throw error;
    } finally {
      draco?.dispose();
    }

    // A newer load() started, or the avatar was disposed, while downloading.
    if (token !== this.#loadToken || this.#disposed) {
      disposeObject3D(gltf.scene);
      return null;
    }

    this.#unloadModel();
    // Clips from separate files come first so they win over same-named ones.
    gltf.animations = [...extraClips, ...gltf.animations];
    if (this.options.inPlaceAnimations) gltf.animations.forEach(removeRootMotion);
    this.#setupModel(gltf);
    this.emit('loaded', {
      animations: this.animationNames,
    });
    return this;
  }

  /**
   * Loads the clips listed in `options.animationUrls` ({ idle, walk, run }).
   * Each file is a .glb with the same skeleton (same bone names) and at least
   * one animation; the first one is used and named Idle / Walk / Run.
   */
  async #loadExternalClips(loader) {
    const urls = this.options.animationUrls ?? {};
    const clips = [];
    for (const [state, clipUrl] of Object.entries(urls)) {
      if (!clipUrl) continue;
      let source;
      try {
        source = await loader.loadAsync(clipUrl);
      } catch (cause) {
        throw new Error(`Could not load the ${state} animation at "${clipUrl}" (${cause?.message ?? cause})`);
      }
      const clip = source.animations[0];
      if (clip) {
        clip.name = state.charAt(0).toUpperCase() + state.slice(1); // Idle / Walk / Run
        clips.push(clip);
      } else {
        console.warn(`[avatar] ${clipUrl} has no animation for "${state}"`);
      }
      disposeObject3D(source.scene); // only the clip is needed, not its copy of the mesh
    }
    return clips;
  }

  /**
   * Plays an animation state by name. Without keyboard input the character
   * animates in place; use the keyboard (or move `position`) to travel.
   */
  setState(state, options) {
    this.#assertAlive();
    if (!this.#loco) throw new Error('The model is not loaded yet');
    this.#manualState = state;
    this.#speed = nominalSpeed(state, this.options);
    this.#loco.setState(state, options);
    this.#loco.setSpeed(this.#speed);
    return this.#loco.state;
  }

  /** Drives the state from a ground speed in m/s (idle < ~0.3 < walk < ~3 < run). */
  setSpeed(speed) {
    this.#assertAlive();
    if (!this.#loco) throw new Error('The model is not loaded yet');
    this.#manualState = null;
    this.#speed = speed;
    return this.#loco.setSpeed(speed);
  }

  /** Names of the extra actions the model offers (wave, cheer, ...). */
  get actionNames() {
    return this.#loco?.actionNames ?? [];
  }

  /**
   * Plays an action clip on the spot: wave, cheer, sad, think, clap, lookaround.
   * Resolves when it ends (or is replaced); resolves false at once if the model
   * does not have it. sad and think hold until stopAction() / setState().
   */
  playAction(name, options) {
    this.#assertAlive();
    if (!this.#loco) return Promise.resolve(false);
    return new Promise((resolve) => {
      if (!this.#loco.playAction(name, options)) return resolve(false);
      const key = name.toLowerCase().replace(/[^a-z]/g, '');
      const off = this.#loco.on('actionend', ({ name: ended }) => {
        if (ended !== key) return;
        off();
        resolve(true);
      });
    });
  }

  stopAction() {
    this.#loco?.stopAction();
  }

  get acting() {
    return this.#loco?.acting ?? null;
  }

  /**
   * Shows what the player has equipped: `frame` ('bronze' | 'silver' | 'gold')
   * is a glowing ring on the floor, `avatar` ('scholar' | 'explorer' |
   * 'champion' | 'genius') an emblem floating above the head. Unknown or empty
   * values remove that item.
   */
  setCosmetics({ avatar, frame } = {}) {
    this.#assertAlive();
    this.#clearCosmetics();
    this.#ring = createFrameRing(frame);
    if (this.#ring) this.#scene.add(this.#ring);
    this.#emblem = createEmblem(avatar);
    if (this.#emblem) this.#scene.add(this.#emblem);
  }

  #clearCosmetics() {
    for (const item of [this.#ring, this.#emblem]) {
      if (!item) continue;
      this.#scene.remove(item);
      disposeObject3D(item);
    }
    this.#ring = null;
    this.#emblem = null;
  }

  /** Half the width (metres) of the ground the camera sees, for the 'strip' framing. */
  visibleHalfWidth() {
    const vFov = THREE.MathUtils.degToRad(this.#camera.fov);
    const distance = Math.abs(this.#camera.position.z - this.#root.position.z);
    return Math.tan(vFov / 2) * distance * this.#camera.aspect;
  }

  /**
   * Walks (or runs, if fast) along the x axis to `toX` in `duration` seconds,
   * facing the direction of travel, then settles facing the camera. Starts at
   * `fromX` (default: where it is now). Resolves on arrival, or when another
   * travel() replaces this one.
   */
  travel({ fromX, toX, duration, endYaw = 0 }) {
    this.#assertAlive();
    this.#path?.done();
    const here = this.#root.position.x;
    const start = fromX ?? here;
    return new Promise((resolve) => {
      this.#manualState = null;
      this.#settleYaw = null;
      this.#root.position.x = start;
      const facing = (toX >= start ? 1 : -1) * (Math.PI / 2);
      if (start !== here) {
        this.#yaw = facing; // entering from off-screen: no visible turn
        this.#root.rotation.y = facing;
      }
      this.#path = { fromX: start, toX, duration: Math.max(0.05, duration), t: 0, endYaw, done: resolve };
    });
  }

  /** A quick jump on the spot (or while walking). */
  hop({ height = 0.45, duration = 0.6 } = {}) {
    this.#assertAlive();
    if (!this.#loco) return;
    // A standing character kicks its legs (Run) for the jump; remember to stand
    // again afterwards, or it would keep running on the spot.
    const restore =
      this.#loco.state === LocomotionState.IDLE && !this.#loco.acting
        ? LocomotionState.IDLE
        : null;
    this.#hop = { t: 0, duration, height, restore };
    if (restore) this.#loco.setState(LocomotionState.RUN);
  }

  /**
   * A graceful spin on the spot: one full turn with a tiny rise onto the toes
   * and a little sparkle. The pose stays as it is (no running legs), so it
   * reads as a happy twirl rather than a jump.
   */
  twirl({ duration = 0.8 } = {}) {
    this.#assertAlive();
    if (!this.#loco || this.#twirl) return;
    this.#twirl = { t: 0, duration, sparked: false };
  }

  /** Stops rendering (e.g. the page is hidden). The pose is kept; `resume()` continues. */
  pause() {
    if (this.#disposed) return;
    this.#renderer.setAnimationLoop(null);
  }

  resume() {
    if (this.#disposed) return;
    this.#startLoop();
  }

  setKeyboardEnabled(enabled) {
    if (this.#input) this.#input.enabled = enabled;
  }

  /**
   * Re-frames the camera on the character: 'full' (whole body), 'bust'
   * (head and shoulders, good for a dashboard card) or 'face' (close-up).
   */
  frameCharacter(framing = 'full') {
    const preset = FRAMINGS[framing];
    if (!preset) throw new Error(`Unknown framing "${framing}". Use full, bust, face or strip.`);
    this.#framing = framing;
    const h = this.#modelHeight;
    const anchor = preset.fixed ? new THREE.Vector3() : this.#root.position;
    const target = anchor.clone().add(new THREE.Vector3(0, h * preset.focus, 0));
    const vFov = THREE.MathUtils.degToRad(this.#camera.fov);
    const hFov = 2 * Math.atan(Math.tan(vFov / 2) * this.#camera.aspect);
    const half = h * preset.half; // half of the height that must stay in view
    const distance = Math.max(half / Math.tan(vFov / 2), (half * 0.55) / Math.tan(hFov / 2));
    const [dx, dy, dz] = preset.dir ?? [0, 0.06, 1]; // straight on: the character faces the viewer
    const offset = new THREE.Vector3(dx, dy, dz).normalize().multiplyScalar(distance);
    this.#camera.position.copy(target).add(offset);
    this.#controls.target.copy(target);
    this.#controls.update();
  }

  resize() {
    if (this.#disposed) return;
    const { clientWidth: w, clientHeight: h } = this.container;
    if (w === 0 || h === 0) return; // hidden or not laid out yet
    this.#renderer.setSize(w, h, false);
    this.#camera.aspect = w / h;
    this.#camera.updateProjectionMatrix();
    if (this.#framing === 'strip' && this.#model) this.frameCharacter('strip');
    if (this.#composer) {
      this.#composer.setPixelRatio(this.#renderer.getPixelRatio());
      this.#composer.setSize(w, h);
    }
  }

  /** Releases everything: GPU memory, audio, listeners and the render loop. */
  dispose() {
    if (this.#disposed) return;
    this.#disposed = true;
    this.#loadToken++;

    this.#renderer.setAnimationLoop(null);
    this.#resizeObserver?.disconnect();
    this.#input?.dispose();
    this.#controls.dispose();
    this.#renderer.domElement.removeEventListener('webglcontextlost', this.#onContextLost);
    this.#renderer.domElement.removeEventListener('webglcontextrestored', this.#onContextRestored);

    this.#clearCosmetics();
    this.#sparkles?.dispose();
    this.#unloadModel();

    this.#env?.dispose();
    this.#scene.environment = null;
    this.#ground.geometry.dispose();
    this.#ground.material.dispose();
    this.#blob.geometry.dispose();
    this.#blob.material.dispose();
    disposeTexture(this.#blobTexture);
    this.#keyLight.shadow.map?.dispose();
    this.#composer?.dispose();
    this.#bloom?.dispose();

    this.#renderer.dispose();
    this.#renderer.forceContextLoss();
    this.#renderer.domElement.remove();
    this.clear();
  }

  // ---- scene -------------------------------------------------------------

  #buildLights() {
    // Soft studio fill: a bright "room" for reflections plus sky/ground bounce.
    const pmrem = new THREE.PMREMGenerator(this.#renderer);
    const room = new RoomEnvironment();
    this.#env = pmrem.fromScene(room, 0.04);
    room.dispose(); // its boxes/lights are only needed to bake the reflection map
    pmrem.dispose();
    this.#scene.environment = this.#env.texture;
    this.#scene.environmentIntensity = 0.45;

    this.#fill = new THREE.HemisphereLight(0xdfe8ff, 0x2b2540, 0.55);
    this.#scene.add(this.#fill);

    const key = new THREE.DirectionalLight(0xfff3e6, 2.1);
    key.position.set(2.8, 5, 3.6);
    key.castShadow = true;
    key.shadow.mapSize.set(this.options.shadowMapSize, this.options.shadowMapSize);
    key.shadow.camera.left = -3;
    key.shadow.camera.right = 3;
    key.shadow.camera.top = 3;
    key.shadow.camera.bottom = -3;
    key.shadow.camera.near = 0.5;
    key.shadow.camera.far = 14;
    key.shadow.bias = -0.0004;
    key.shadow.normalBias = 0.025;
    key.shadow.radius = 4;
    this.#scene.add(key, key.target);
    this.#keyLight = key;

    // Two lights from behind, one each side, so the silhouette stands out
    // from the card behind it. setStyle() tunes them for dark / light themes.
    this.#rimA = new THREE.DirectionalLight(0x7fd8ff, 1.1);
    this.#rimA.position.set(-3, 2.6, -4);
    this.#rimB = new THREE.DirectionalLight(0xffb27a, 0.6);
    this.#rimB.position.set(3, 2.2, -4);
    this.#scene.add(this.#rimA, this.#rimB);
    this.#sparkles = new Sparkles(this.#scene);
  }

  /**
   * Adapts the lighting to the app's theme: `dark` strengthens the back lights
   * so the character glows against a dark card; `accent` (a CSS colour) tints
   * the left back light and the sparkles.
   */
  setStyle({ dark = true, accent = '#8b7bff' } = {}) {
    this.#assertAlive();
    const tint = new THREE.Color(accent);
    this.#rimA.color.set(0x7fd8ff).lerp(tint, 0.55);
    this.#rimA.intensity = dark ? 2.0 : 0.9;
    this.#rimB.intensity = dark ? 1.3 : 0.5;
    this.#fill.intensity = dark ? 0.75 : 0.5;
    this.#renderer.toneMappingExposure = dark ? 1.12 : 1.0;
    this.#sparkles.accent.copy(tint);
  }

  /** A burst of sparkles above the character (e.g. when a prize is won). */
  sparkle({ n = 18, height = 1.9 } = {}) {
    this.#assertAlive();
    const p = this.#root.position;
    this.#sparkles.burst({ x: p.x, y: height, z: p.z }, { n, speed: 1.5, upward: 1.5, spread: 0.3 });
  }

  #buildGround() {
    // Soft shadow of the key light on the floor.
    this.#ground = new THREE.Mesh(
      new THREE.PlaneGeometry(14, 14).rotateX(-Math.PI / 2),
      new THREE.ShadowMaterial({ opacity: 0.32 }),
    );
    this.#ground.receiveShadow = true;
    this.#scene.add(this.#ground);

    // Contact shadow: a dark soft blob right under the feet, so the character
    // never looks like it floats even where the key shadow is faint.
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = 128;
    const g = canvas.getContext('2d');
    const gradient = g.createRadialGradient(64, 64, 0, 64, 64, 64);
    gradient.addColorStop(0, 'rgba(0,0,0,0.85)');
    gradient.addColorStop(0.55, 'rgba(0,0,0,0.35)');
    gradient.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = gradient;
    g.fillRect(0, 0, 128, 128);
    this.#blobTexture = new THREE.CanvasTexture(canvas);
    this.#blobTexture.colorSpace = THREE.SRGBColorSpace;
    this.#blob = new THREE.Mesh(
      new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2),
      new THREE.MeshBasicMaterial({
        map: this.#blobTexture,
        transparent: true,
        depthWrite: false,
        opacity: 0.6,
      }),
    );
    this.#blob.position.y = 0.002;
    this.#blob.renderOrder = -1;
    this.#scene.add(this.#blob);
  }

  #buildComposer() {
    const size = this.#renderer.getSize(new THREE.Vector2());
    const target = new THREE.WebGLRenderTarget(size.x || 1, size.y || 1, {
      type: THREE.HalfFloatType,
      samples: 4, // keeps edges smooth (the composer bypasses canvas MSAA)
    });
    const composer = new EffectComposer(this.#renderer, target);
    composer.addPass(new RenderPass(this.#scene, this.#camera));
    // Only HDR-bright pixels (the boosted neon) pass the threshold and glow.
    this.#bloom = new UnrealBloomPass(
      new THREE.Vector2(size.x || 1, size.y || 1),
      this.options.bloomStrength,
      0.55,
      1.0,
    );
    composer.addPass(this.#bloom);
    composer.addPass(new OutputPass()); // tone mapping + sRGB
    this.#composer = composer;
  }

  // ---- model -------------------------------------------------------------

  #setupModel(gltf) {
    const model = gltf.scene;
    const o = this.options;

    // Stand the model on the floor, centred, at the requested height.
    const box = new THREE.Box3().setFromObject(model);
    const size = box.getSize(new THREE.Vector3());
    const scale = size.y > 0 ? o.targetHeight / size.y : 1;
    model.scale.multiplyScalar(scale);
    box.setFromObject(model);
    const center = box.getCenter(new THREE.Vector3());
    model.position.set(-center.x, -box.min.y, -center.z);
    this.#modelHeight = o.targetHeight;

    this.#glowMaterials = [];
    const seen = new Set();
    model.traverse((object) => {
      if (!object.isMesh) return;
      object.castShadow = true;
      object.receiveShadow = true;
      object.frustumCulled = false; // skinned bounds do not follow the pose
      for (const material of [].concat(object.material)) {
        if (!seen.has(material)) {
          seen.add(material);
          this.#prepareMaterial(material);
        }
      }
    });

    this.#root.add(model);
    this.#model = model;
    this.#root.rotation.y = this.#yaw;

    this.#mixer = new THREE.AnimationMixer(model);
    this.#loco = new LocomotionController(this.#mixer, gltf.animations, o);
    this.#loco.on('change', (change) => this.emit('statechange', change));

    // Draw one invisible sparkle now, so its shader is compiled while the page is
    // still hidden (otherwise the first jump or cheer would hitch to compile it).
    this.#sparkles.burst({ x: 0, y: -5, z: 0 }, { n: 1, speed: 0, upward: 0, spread: 0 });

    this.#blob.scale.setScalar(o.targetHeight * 0.55);
    this.#loco.setState(LocomotionState.IDLE, { immediate: true });
    this.frameCharacter();
  }

  /** Makes "neon" materials glow: boosts emissive so bloom picks them up. */
  #prepareMaterial(material) {
    if (!material.isMeshStandardMaterial && !material.isMeshPhysicalMaterial) return;
    const named = /neon|glow|emissive|led/i.test(material.name);
    const emits = material.emissive && material.emissive.getHex() !== 0x000000;
    if (!named && !emits) return;
    if (!emits) material.emissive.copy(material.color);
    material.emissiveIntensity = Math.max(material.emissiveIntensity, this.options.glowIntensity);
    material.toneMapped = true;
    this.#glowMaterials.push(material);
  }

  #unloadModel() {
    this.#loco?.dispose();
    this.#loco = null;
    if (this.#mixer) {
      this.#mixer.stopAllAction();
      if (this.#model) this.#mixer.uncacheRoot(this.#model);
      this.#mixer = null;
    }
    if (this.#model) {
      this.#root.remove(this.#model);
      disposeObject3D(this.#model);
      this.#model = null;
    }
    this.#glowMaterials = [];
  }

  // ---- frame loop --------------------------------------------------------

  #startLoop() {
    this.#lastTime = performance.now();
    this.#renderer.setAnimationLoop(this.#tick);
  }

  #tick = (now) => {
    if (this.#disposed) return;
    const dt = Math.min((now - this.#lastTime) / 1000, 0.1); // clamp after tab switches
    this.#lastTime = now;

    this.#updateMovement(dt);

    if (this.#mixer) {
      this.#mixer.update(dt);
    }

    this.#sparkles?.update(dt);
    this.#controls.update();
    if (this.#composer) this.#composer.render(dt);
    else this.#renderer.render(this.#scene, this.#camera);
  };

  #updateMovement(dt) {
    if (!this.#loco) return;
    const o = this.options;
    const input = this.#input?.axes;

    if (this.#path) {
      const path = this.#path;
      path.t = Math.min(path.duration, path.t + dt);
      const u = path.t / path.duration;
      this.#root.position.x = path.fromX + (path.toX - path.fromX) * u;
      this.#speed = Math.abs(path.toX - path.fromX) / path.duration;
      const facing = (path.toX >= path.fromX ? 1 : -1) * (Math.PI / 2);
      this.#yaw += shortestAngle(this.#yaw, facing) * (1 - Math.exp(-14 * dt));
      this.#root.rotation.y = this.#yaw;
      this.#loco.setSpeed(this.#speed);
      if (path.t >= path.duration) {
        this.#path = null;
        this.#settleYaw = path.endYaw;
        // Arrived: stand still now, so what the caller starts next (a pose) is
        // not cut short by the walk slowing down.
        this.#speed = 0;
        this.#loco.setSpeed(0);
        path.done();
      }
    } else if (input?.active) {
      this.#settleYaw = null;
      // Keys take over from a code-chosen state.
      this.#manualState = null;
      const target = input.run ? o.runSpeed : o.walkSpeed;
      this.#speed += (target - this.#speed) * (1 - Math.exp(-10 * dt));

      // Move relative to where the camera looks, on the ground plane.
      const forward = new THREE.Vector3();
      this.#camera.getWorldDirection(forward);
      forward.y = 0;
      forward.normalize();
      const right = new THREE.Vector3().crossVectors(forward, new THREE.Vector3(0, 1, 0));
      const dir = forward.multiplyScalar(input.z).add(right.multiplyScalar(input.x)).normalize();

      const step = dir.clone().multiplyScalar(this.#speed * dt);
      const next = this.#root.position.clone().add(step);
      if (next.length() > o.moveRadius) next.setLength(o.moveRadius);
      const moved = next.clone().sub(this.#root.position);
      this.#root.position.copy(next);
      this.#camera.position.add(moved); // the camera follows without re-aiming
      this.#controls.target.add(moved);

      const targetYaw = Math.atan2(dir.x, dir.z); // glTF models face +Z
      this.#yaw += shortestAngle(this.#yaw, targetYaw) * (1 - Math.exp(-12 * dt));
      this.#root.rotation.y = this.#yaw;
      this.#loco.setSpeed(this.#speed);
    } else if (this.#manualState === null) {
      // Keys released: slow down and settle into Idle.
      this.#speed += (0 - this.#speed) * (1 - Math.exp(-9 * dt));
      if (this.#speed < 0.02) this.#speed = 0;
      if (!this.#hop) this.#loco.setSpeed(this.#speed);
      if (this.#settleYaw !== null) {
        this.#yaw += shortestAngle(this.#yaw, this.#settleYaw) * (1 - Math.exp(-6 * dt));
        this.#root.rotation.y = this.#yaw;
      }
    }

    // A hop lifts the whole character and shrinks the contact shadow.
    let lift = 0;
    if (this.#hop) {
      const hop = this.#hop;
      hop.t += dt;
      const u = hop.t / hop.duration;
      if (u >= 1) {
        this.#hop = null;
        // Back to standing, unless the app chose something else meanwhile
        // (e.g. the "hurry" run, or an action such as a wave).
        if (
          hop.restore &&
          this.#manualState === hop.restore &&
          this.#loco.state === LocomotionState.RUN &&
          !this.#loco.acting
        ) {
          this.#loco.setState(hop.restore);
        }
        this.#sparkles.burst(
          { x: this.#root.position.x, y: 0.06, z: this.#root.position.z },
          { n: 7, speed: 0.9, upward: 0.9, spread: 0.18 },
        );
      } else {
        lift = 4 * hop.height * u * (1 - u);
      }
    }
    if (this.#twirl) {
      const tw = this.#twirl;
      tw.t += dt;
      const u = Math.min(1, tw.t / tw.duration);
      // Ease in and out so the turn starts and stops softly.
      const eased = u * u * (3 - 2 * u);
      this.#root.rotation.y = this.#yaw + eased * Math.PI * 2;
      lift += 0.07 * Math.sin(Math.PI * u);
      if (!tw.sparked) {
        tw.sparked = true;
        this.#sparkles.burst(
          { x: this.#root.position.x, y: 0.9, z: this.#root.position.z },
          { n: 12, speed: 1.1, upward: 0.5, spread: 0.45 },
        );
      }
      if (u >= 1) {
        this.#twirl = null;
        this.#root.rotation.y = this.#yaw;
      }
    }
    this.#root.position.y = lift;
    this.#clock += dt;
    const acting = this.#loco.acting;
    if (acting === 'cheer') {
      this.#burstTimer -= dt;
      const first = this.#lastActing !== 'cheer';
      if (first || this.#burstTimer <= 0) {
        this.#burstTimer = 0.26;
        const side = Math.random() < 0.5 ? -1 : 1;
        this.#sparkles.burst(
          {
            x: this.#root.position.x + side * (0.35 + Math.random() * 0.25),
            y: 1.3 + Math.random() * 0.35,
            z: this.#root.position.z,
          },
          { n: first ? 28 : 14, speed: 1.2, upward: 0.9, spread: 0.25 },
        );
      }
    }
    this.#lastActing = acting;
    if (this.#ring) {
      this.#ring.position.set(this.#root.position.x, 0.012, this.#root.position.z);
      this.#ring.userData.update(this.#clock);
    }
    if (this.#emblem) {
      this.#emblem.position.set(
        this.#root.position.x,
        this.options.targetHeight * 1.06 + lift,
        this.#root.position.z,
      );
      this.#emblem.userData.update(this.#clock);
    }
    this.#blob.scale.setScalar(this.options.targetHeight * 0.55 * (1 - Math.min(0.5, lift)));

    // Shadows and the contact blob stay under the character.
    const p = this.#root.position;
    this.#ground.position.set(p.x, 0, p.z);
    this.#blob.position.set(p.x, 0.002, p.z);
    this.#keyLight.position.set(p.x + 2.8, 5, p.z + 3.6);
    this.#keyLight.target.position.set(p.x, 0, p.z);
  }

  #assertAlive() {
    if (this.#disposed) throw new Error('This avatar was disposed');
  }
}

/**
 * Clips exported from animation libraries (Meshy, Mixamo) often move the hips
 * through the world. The avatar moves itself, so flatten hips X/Z travel and
 * keep the vertical bounce.
 */
function removeRootMotion(clip) {
  for (const track of clip.tracks) {
    if (!track.name.endsWith('.position')) continue;
    const node = track.name.slice(0, -'.position'.length);
    if (!/(^|[^a-z])(hips|pelvis|root)$/i.test(node) && !/^mixamorig:?hips$/i.test(node)) continue;
    const v = track.values;
    for (let i = 0; i < v.length; i += 3) {
      v[i] = v[0];
      v[i + 2] = v[2];
    }
  }
}
