import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  LocomotionState as S,
  clipTimeScale,
  nextLocomotionState,
  nominalSpeed,
  shortestAngle,
} from '../src/locomotionLogic.js';

test('speed picks Idle / Walk / Run', () => {
  assert.equal(nextLocomotionState(S.IDLE, 0), S.IDLE);
  assert.equal(nextLocomotionState(S.IDLE, 1.6), S.WALK);
  assert.equal(nextLocomotionState(S.IDLE, 4.2), S.RUN); // jumps straight to run
  assert.equal(nextLocomotionState(S.RUN, 0), S.IDLE);
});

test('hysteresis: a speed on a threshold does not flicker', () => {
  // Idle -> Walk needs 0.3, Walk -> Idle needs to drop below 0.15.
  let state = S.IDLE;
  const seen = [];
  for (const speed of [0.31, 0.25, 0.2, 0.28, 0.2, 0.16]) {
    state = nextLocomotionState(state, speed);
    seen.push(state);
  }
  assert.deepEqual(new Set(seen), new Set([S.WALK]));
  assert.equal(nextLocomotionState(S.WALK, 0.1), S.IDLE);

  // Walk <-> Run around the midpoint (2.3) behaves the same way.
  assert.equal(nextLocomotionState(S.WALK, 2.4), S.WALK);
  assert.equal(nextLocomotionState(S.WALK, 2.7), S.RUN);
  assert.equal(nextLocomotionState(S.RUN, 2.4), S.RUN);
  assert.equal(nextLocomotionState(S.RUN, 1.9), S.WALK);
});

test('clip speed matches ground speed within a natural range', () => {
  assert.equal(clipTimeScale(S.IDLE, 5), 1);
  assert.equal(clipTimeScale(S.WALK, 1.3), 1);
  assert.equal(clipTimeScale(S.WALK, 0.1), 0.6); // never crawls
  assert.equal(clipTimeScale(S.WALK, 9), 1.5);
  assert.equal(clipTimeScale(S.RUN, 3.3), 1);
  assert.equal(nominalSpeed(S.RUN), 3.3);
  assert.equal(nominalSpeed(S.IDLE), 0);
});

test('shortestAngle turns the short way round', () => {
  assert.ok(Math.abs(shortestAngle(0.1, -0.1) + 0.2) < 1e-9);
  assert.ok(Math.abs(shortestAngle(3.0, -3.0) - (2 * Math.PI - 6)) < 1e-9);
});
