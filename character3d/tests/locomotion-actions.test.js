import assert from 'node:assert/strict';
import { test } from 'node:test';
import * as THREE from 'three';

import { LocomotionController } from '../src/LocomotionController.js';

function rig() {
  const root = new THREE.Object3D();
  const bone = new THREE.Bone();
  bone.name = 'Hips';
  root.add(bone);
  const clip = (name, duration = 1) =>
    new THREE.AnimationClip(name, duration, [
      new THREE.VectorKeyframeTrack('Hips.position', [0, duration], [0, 0, 0, 0, 1, 0]),
    ]);
  const mixer = new THREE.AnimationMixer(root);
  const loco = new LocomotionController(mixer, [
    clip('Idle'),
    clip('Walk'),
    clip('Run'),
    clip('Wave', 0.5),
    clip('Think'),
    clip('LookAround', 0.5),
  ]);
  loco.setState('idle', { immediate: true });
  return { mixer, loco };
}

test('every clip that is not Idle/Walk/Run becomes an action', () => {
  const { loco } = rig();
  assert.deepEqual(loco.actionNames.sort(), ['lookaround', 'think', 'wave']);
  assert.equal(loco.playAction('Look Around'), true); // names are forgiving
  assert.equal(loco.playAction('moonwalk'), false); // unknown: nothing happens
});

test('a one-shot action plays, then returns to the state underneath', () => {
  const { loco, mixer } = rig();
  const events = [];
  loco.on('action', (e) => events.push(`start:${e.name}`));
  loco.on('actionend', (e) => events.push(`end:${e.name}`));
  loco.playAction('wave');
  assert.equal(loco.acting, 'wave');
  assert.equal(loco.state, 'idle'); // the underlying state is unchanged
  for (let i = 0; i < 40; i++) mixer.update(0.05); // longer than the clip
  assert.equal(loco.acting, null);
  assert.deepEqual(events, ['start:wave', 'end:wave']);
});

test('standing still does not interrupt an action, moving does', () => {
  const { loco } = rig();
  loco.playAction('wave');
  loco.setSpeed(0); // idle stays idle: the wave goes on
  assert.equal(loco.acting, 'wave');
  loco.setSpeed(1.3); // starts walking: the wave ends
  assert.equal(loco.acting, null);
  assert.equal(loco.state, 'walk');
});

test('held actions last until stopped or until a state is chosen', () => {
  const { loco, mixer } = rig();
  loco.playAction('think');
  for (let i = 0; i < 100; i++) mixer.update(0.05);
  assert.equal(loco.acting, 'think'); // still thinking after 5 s
  loco.stopAction();
  assert.equal(loco.acting, null);

  loco.playAction('think');
  assert.equal(loco.setState('idle'), 'idle'); // same state: just ends the action
  assert.equal(loco.acting, null);
  loco.playAction('think');
  assert.equal(loco.setState('run'), 'run');
  assert.equal(loco.acting, null);
});

test('a new action replaces the one that is playing', () => {
  const { loco } = rig();
  loco.playAction('think');
  loco.playAction('wave');
  assert.equal(loco.acting, 'wave');
});
