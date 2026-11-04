import * as THREE from 'three';

import { Emitter } from './emitter.js';
import {
  DEFAULT_SPEEDS,
  LocomotionState,
  clipTimeScale,
  nextLocomotionState,
  nominalSpeed,
} from './locomotionLogic.js';

/** Names accepted for each state, matched as a case-insensitive substring. */
const CLIP_ALIASES = {
  [LocomotionState.IDLE]: ['idle', 'stand', 'breath'],
  [LocomotionState.WALK]: ['walk'],
  [LocomotionState.RUN]: ['run', 'jog', 'sprint'],
};

/** When a clip is missing, play the nearest one instead of freezing. */
const FALLBACK = {
  [LocomotionState.IDLE]: [],
  [LocomotionState.WALK]: [LocomotionState.IDLE],
  [LocomotionState.RUN]: [LocomotionState.WALK, LocomotionState.IDLE],
};

/**
 * Idle / Walk / Run state machine with smooth cross-fades.
 *
 *   loco.setState('run')   - play a state by name
 *   loco.setSpeed(2.4)     - pick the state (and foot speed) from ground speed
 *
 * Emits 'change' with { from, to } whenever the playing state changes.
 */
export class LocomotionController extends Emitter {
  #mixer;
  #actions = new Map(); // state -> AnimationAction
  #state = null;
  #speeds;
  #fade;

  constructor(mixer, clips, { fadeDuration = 0.25, ...speeds } = {}) {
    super();
    this.#mixer = mixer;
    this.#fade = fadeDuration;
    this.#speeds = { ...DEFAULT_SPEEDS, ...speeds };

    for (const state of Object.values(LocomotionState)) {
      const clip = findClip(clips, CLIP_ALIASES[state]);
      if (clip) {
        const action = mixer.clipAction(clip);
        action.setLoop(THREE.LoopRepeat, Infinity);
        this.#actions.set(state, action);
      } else {
        console.warn(`[avatar] no "${state}" clip found in the model`);
      }
    }
    // A single clip with an unfamiliar name (e.g. "Armature|mixamo.com|Layer0")
    // is the walk cycle: that is what a "walking" download from an
    // animation library contains.
    if (this.#actions.size === 0 && clips.length > 0) {
      const action = mixer.clipAction(clips[0]);
      action.setLoop(THREE.LoopRepeat, Infinity);
      this.#actions.set(LocomotionState.WALK, action);
      console.warn(`[avatar] using clip "${clips[0].name}" as the walk animation`);
    }
    this.clipNames = clips.map((clip) => clip.name);
  }

  get state() {
    return this.#state;
  }

  get hasClips() {
    return this.#actions.size > 0;
  }

  /** Plays [state] (cross-fading from the current one). Returns the state used. */
  setState(state, { immediate = false } = {}) {
    if (!Object.values(LocomotionState).includes(state)) {
      throw new Error(`Unknown state "${state}". Use idle, walk or run.`);
    }
    const resolved = this.#resolve(state);
    if (!resolved || resolved === this.#state) return this.#state;

    const next = this.#actions.get(resolved);
    const previous = this.#state ? this.#actions.get(this.#state) : null;
    const from = this.#state;

    next.enabled = true;
    next.setEffectiveWeight(1);
    next.setEffectiveTimeScale(1);
    next.reset();
    // Walk <-> Run: start at the same point of the stride, so feet do not pop.
    if (previous && isCycle(from) && isCycle(resolved)) {
      const phase = previous.time / previous.getClip().duration;
      next.time = phase * next.getClip().duration;
    }
    next.play();

    if (previous && !immediate) {
      previous.crossFadeTo(next, this.#fade, false);
    } else if (previous) {
      previous.stop();
    } else {
      next.fadeIn(immediate ? 0 : this.#fade);
    }

    this.#state = resolved;
    this.emit('change', { from, to: resolved });
    return resolved;
  }

  /**
   * Chooses the state from a ground speed in metres/second (with hysteresis)
   * and matches the foot speed. Returns the current state.
   */
  setSpeed(speed) {
    const next = nextLocomotionState(this.#state ?? LocomotionState.IDLE, speed, this.#speeds);
    this.setState(next);
    this.#applyTimeScale(speed);
    return this.#state;
  }

  /** Speed (m/s) a state was authored for, for code-chosen states. */
  nominalSpeed(state) {
    return nominalSpeed(state, this.#speeds);
  }

  #applyTimeScale(speed) {
    const action = this.#state ? this.#actions.get(this.#state) : null;
    if (action) action.setEffectiveTimeScale(clipTimeScale(this.#state, speed, this.#speeds));
  }

  #resolve(state) {
    if (this.#actions.has(state)) return state;
    for (const fallback of FALLBACK[state]) {
      if (this.#actions.has(fallback)) return fallback;
    }
    // Last resort: any clip at all, so the character is never frozen.
    const [first] = this.#actions.keys();
    return first ?? null;
  }

  dispose() {
    this.#mixer.stopAllAction();
    this.#actions.clear();
    this.clear();
  }
}

function isCycle(state) {
  return state === LocomotionState.WALK || state === LocomotionState.RUN;
}

function findClip(clips, aliases) {
  const lower = clips.map((clip) => ({ clip, name: clip.name.toLowerCase() }));
  // Exact name first ("Idle"), then any name containing an alias.
  for (const alias of aliases) {
    const exact = lower.find((c) => c.name === alias || c.name.endsWith(`|${alias}`));
    if (exact) return exact.clip;
  }
  for (const alias of aliases) {
    const partial = lower.find((c) => c.name.includes(alias));
    if (partial) return partial.clip;
  }
  return null;
}
