// Pure movement rules (no three.js), so they can be unit-tested in Node.

export const LocomotionState = Object.freeze({
  IDLE: 'idle',
  WALK: 'walk',
  RUN: 'run',
});

export const DEFAULT_SPEEDS = Object.freeze({
  walkSpeed: 1.3, // metres per second the Walk clip was authored for
  runSpeed: 3.3, // metres per second the Run clip was authored for
});

/**
 * Picks Idle / Walk / Run from a speed (m/s). Enter and exit thresholds differ
 * (hysteresis), so a speed hovering around a limit never makes the animation
 * flicker between two states.
 */
export function nextLocomotionState(current, speed, speeds = DEFAULT_SPEEDS) {
  const { walkSpeed, runSpeed } = { ...DEFAULT_SPEEDS, ...speeds };
  const runAt = (walkSpeed + runSpeed) / 2;
  const walkEnter = 0.3;
  const walkExit = 0.15;
  const runEnter = runAt + 0.3;
  const runExit = runAt - 0.3;

  let s = current;
  if (s === LocomotionState.IDLE && speed >= walkEnter) s = LocomotionState.WALK;
  if (s === LocomotionState.WALK && speed >= runEnter) s = LocomotionState.RUN;
  else if (s === LocomotionState.RUN && speed < runExit) s = LocomotionState.WALK;
  if (s === LocomotionState.WALK && speed < walkExit) s = LocomotionState.IDLE;
  return s;
}

/**
 * Playback speed for a clip so the feet match the ground speed. Kept inside a
 * range where the cycle still looks natural.
 */
export function clipTimeScale(state, speed, speeds = DEFAULT_SPEEDS) {
  const { walkSpeed, runSpeed } = { ...DEFAULT_SPEEDS, ...speeds };
  if (state === LocomotionState.WALK) return clamp(speed / walkSpeed, 0.6, 1.5);
  if (state === LocomotionState.RUN) return clamp(speed / runSpeed, 0.7, 1.4);
  return 1;
}

/** Ground speed to use for a state that was chosen by code, not by input. */
export function nominalSpeed(state, speeds = DEFAULT_SPEEDS) {
  const { walkSpeed, runSpeed } = { ...DEFAULT_SPEEDS, ...speeds };
  if (state === LocomotionState.WALK) return walkSpeed;
  if (state === LocomotionState.RUN) return runSpeed;
  return 0;
}

/** Shortest signed angle from a to b, in radians. */
export function shortestAngle(a, b) {
  let d = (b - a) % (Math.PI * 2);
  if (d > Math.PI) d -= Math.PI * 2;
  if (d < -Math.PI) d += Math.PI * 2;
  return d;
}

export function clamp(v, min, max) {
  return Math.min(max, Math.max(min, v));
}
