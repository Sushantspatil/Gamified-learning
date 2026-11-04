import assert from 'node:assert/strict';
import { test } from 'node:test';
import * as THREE from 'three';

import { LocomotionController } from '../src/LocomotionController.js';

function rig() {
  const root = new THREE.Object3D();
  const bone = new THREE.Bone();
  bone.name = 'Hips';
  root.add(bone);
  const clip = (name) =>
    new THREE.AnimationClip(name, 1, [
      new THREE.VectorKeyframeTrack('Hips.position', [0, 1], [0, 0, 0, 0, 1, 0]),
    ]);
  return { mixer: new THREE.AnimationMixer(root), clip };
}

test('named Idle / Walk / Run clips are found', () => {
  const { mixer, clip } = rig();
  const loco = new LocomotionController(mixer, [clip('Idle'), clip('Walking'), clip('run_fast')]);
  assert.equal(loco.setState('walk'), 'walk');
  assert.equal(loco.setState('run'), 'run');
  assert.equal(loco.setState('idle'), 'idle');
});

test('a single oddly named clip is used as the walk cycle', () => {
  const { mixer, clip } = rig();
  const warn = console.warn;
  console.warn = () => {};
  const loco = new LocomotionController(mixer, [clip('Armature|mixamo.com|Layer0')]);
  console.warn = warn;
  assert.equal(loco.setState('walk'), 'walk');
  // Asking for Idle or Run still shows the walk, never a frozen character.
  assert.equal(loco.setState('idle'), 'walk');
  assert.equal(loco.setState('run'), 'walk');
});

test('a model without clips does not crash and reports no state', () => {
  const { mixer } = rig();
  const warn = console.warn;
  console.warn = () => {};
  const loco = new LocomotionController(mixer, []);
  console.warn = warn;
  assert.equal(loco.hasClips, false);
  assert.equal(loco.setState('walk'), null);
});

test('unknown state names are rejected', () => {
  const { mixer, clip } = rig();
  const loco = new LocomotionController(mixer, [clip('Walk')]);
  assert.throws(() => loco.setState('fly'));
});
