// Runs in the browser (see make-test-model.mjs). Builds a small stand-in avatar:
// a skinned humanoid with "Idle", "Walk" and "Run" clips, a neon visor material,
// and a head with jawOpen / viseme_* / eyeBlink* blendshapes. It exists only so
// the viewer, locomotion and lip-sync can be tried and tested before the real
// character is exported. It is NOT the product's character.
import * as THREE from 'three';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

const bones = {};
function bone(name, x, y, z, parent) {
  const b = new THREE.Bone();
  b.name = name;
  b.position.set(x, y, z);
  parent?.add(b);
  bones[name] = b;
  return b;
}

// ---- skeleton (metres, facing +Z, feet at y=0) ----------------------------
const hips = bone('Hips', 0, 0.95, 0);
const spine = bone('Spine', 0, 0.12, 0, hips);
const chest = bone('Chest', 0, 0.2, 0, spine);
const neck = bone('Neck', 0, 0.2, 0, chest);
const head = bone('Head', 0, 0.1, 0, neck);
for (const [side, sx] of [['Left', 1], ['Right', -1]]) {
  const up = bone(`${side}UpLeg`, 0.1 * sx, -0.02, 0, hips);
  bone(`${side}Leg`, 0, -0.45, 0, up);
  const arm = bone(`${side}Arm`, 0.2 * sx, 0.14, 0, chest);
  bone(`${side}ForeArm`, 0, -0.3, 0, arm);
}
hips.updateMatrixWorld(true);

const boneList = Object.values(bones);
const index = (name) => boneList.findIndex((b) => b.name === name);
const worldY = (name) => new THREE.Vector3().setFromMatrixPosition(bones[name].matrixWorld);

// ---- body geometry, one rigid piece per bone ------------------------------
function part(geometry, boneName, color, at) {
  geometry.translate(at.x, at.y, at.z);
  const count = geometry.attributes.position.count;
  const skinIndex = new Uint16Array(count * 4);
  const skinWeight = new Float32Array(count * 4);
  for (let i = 0; i < count; i++) {
    skinIndex[i * 4] = index(boneName);
    skinWeight[i * 4] = 1;
  }
  geometry.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(skinIndex, 4));
  geometry.setAttribute('skinWeight', new THREE.Float32BufferAttribute(skinWeight, 4));
  const colors = new Float32Array(count * 3);
  const c = new THREE.Color(color);
  for (let i = 0; i < count; i++) c.toArray(colors, i * 3);
  geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
  return geometry;
}
const mid = (a, b) => worldY(a).add(worldY(b)).multiplyScalar(0.5);

const SHIRT = 0x3d5afe;
const PANTS = 0x263238;
const SKIN = 0xf1c27d;
const parts = [
  part(new THREE.CapsuleGeometry(0.17, 0.3, 6, 16), 'Spine', SHIRT, mid('Spine', 'Chest')),
  part(new THREE.BoxGeometry(0.34, 0.16, 0.2), 'Hips', PANTS, worldY('Hips')),
  part(new THREE.CylinderGeometry(0.045, 0.05, 0.17, 12), 'Neck', SKIN, worldY('Neck')),
];
for (const side of ['Left', 'Right']) {
  parts.push(
    part(new THREE.CapsuleGeometry(0.08, 0.32, 6, 12), `${side}UpLeg`, PANTS, mid(`${side}UpLeg`, `${side}Leg`)),
    part(new THREE.CapsuleGeometry(0.065, 0.34, 6, 12), `${side}Leg`, PANTS, worldY(`${side}Leg`).add(new THREE.Vector3(0, -0.22, 0))),
    part(new THREE.BoxGeometry(0.11, 0.07, 0.24), `${side}Leg`, 0x111111, worldY(`${side}Leg`).add(new THREE.Vector3(0, -0.44, 0.05))),
    part(new THREE.CapsuleGeometry(0.055, 0.2, 6, 12), `${side}Arm`, SHIRT, mid(`${side}Arm`, `${side}ForeArm`)),
    part(new THREE.CapsuleGeometry(0.048, 0.2, 6, 12), `${side}ForeArm`, SKIN, worldY(`${side}ForeArm`).add(new THREE.Vector3(0, -0.17, 0))),
  );
}
const bodyGeometry = mergeGeometries(parts.map((g) => g.toNonIndexed()));

// ---- head with blendshapes -------------------------------------------------
const headPos = worldY('Head');
const headCenter = headPos.clone().add(new THREE.Vector3(0, 0.075, 0));
const tags = []; // per vertex: 0 skin, 1 left eye, 2 right eye, 3 mouth
function headPart(source, color, tag, at) {
  source.translate(at.x, at.y, at.z);
  // Convert first: the per-vertex tags must match the final (non-indexed) vertices.
  const geometry = source.toNonIndexed();
  const n = geometry.attributes.position.count;
  const colors = new Float32Array(n * 3);
  const c = new THREE.Color(color);
  for (let i = 0; i < n; i++) {
    c.toArray(colors, i * 3);
    tags.push(tag);
  }
  geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
  const si = new Uint16Array(n * 4);
  const sw = new Float32Array(n * 4);
  for (let i = 0; i < n; i++) {
    si[i * 4] = index('Head');
    sw[i * 4] = 1;
  }
  geometry.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(si, 4));
  geometry.setAttribute('skinWeight', new THREE.Float32BufferAttribute(sw, 4));
  return geometry;
}
const mouthCenter = headCenter.clone().add(new THREE.Vector3(0, -0.045, 0.092));
const headGeometry = mergeGeometries([
  headPart(new THREE.SphereGeometry(0.11, 24, 16), SKIN, 0, headCenter),
  headPart(new THREE.SphereGeometry(0.018, 12, 10), 0x1b1b1b, 1, headCenter.clone().add(new THREE.Vector3(0.04, 0.025, 0.098))),
  headPart(new THREE.SphereGeometry(0.018, 12, 10), 0x1b1b1b, 2, headCenter.clone().add(new THREE.Vector3(-0.04, 0.025, 0.098))),
  headPart(new THREE.SphereGeometry(0.03, 16, 12).scale(1.3, 0.35, 0.5), 0x7a1f2b, 3, mouthCenter),
]);

function morph(fn) {
  const pos = headGeometry.attributes.position;
  const out = new Float32Array(pos.count * 3);
  for (let i = 0; i < pos.count; i++) {
    const v = new THREE.Vector3().fromBufferAttribute(pos, i);
    const d = fn(v, tags[i]) ?? [0, 0, 0];
    out[i * 3] = d[0];
    out[i * 3 + 1] = d[1];
    out[i * 3 + 2] = d[2];
  }
  return new THREE.Float32BufferAttribute(out, 3);
}
const lowerFace = (v, tag) => tag === 0 && v.y < headCenter.y - 0.03 && v.z > headCenter.z;
// Opens the mouth by `open` metres and narrows/widens it by `wide`.
const mouthShape = (open, wide) => (v, tag) => {
  if (tag === 3) {
    return [(v.x - mouthCenter.x) * wide, (v.y - mouthCenter.y) * open * 40 - open * 0.6, 0];
  }
  if (lowerFace(v, tag)) return [(v.x - headCenter.x) * wide * 0.4, -open * 0.9, 0];
  return null;
};
const blink = (side) => (v, tag) =>
  tag === side ? [0, -(v.y - (headCenter.y + 0.025)) * 0.95, 0] : null;

const morphNames = {
  jawOpen: mouthShape(0.04, 0),
  viseme_aa: mouthShape(0.035, 0.1),
  viseme_O: mouthShape(0.022, -0.5),
  viseme_E: mouthShape(0.014, 0.5),
  viseme_I: mouthShape(0.008, 0.7),
  viseme_U: mouthShape(0.012, -0.7),
  eyeBlinkLeft: blink(1),
  eyeBlinkRight: blink(2),
};
headGeometry.morphAttributes.position = Object.values(morphNames).map((fn) => morph(fn));
headGeometry.morphTargetsRelative = true;

// ---- neon visor ------------------------------------------------------------
const visorGeometry = headPart(
  new THREE.BoxGeometry(0.2, 0.03, 0.02),
  0xffffff,
  0,
  headCenter.clone().add(new THREE.Vector3(0, 0.075, 0.098)),
);
const stripGeometry = part(new THREE.BoxGeometry(0.2, 0.025, 0.02), 'Chest', 0xffffff, worldY('Chest').add(new THREE.Vector3(0, 0.02, 0.17)));

// ---- meshes ---------------------------------------------------------------
const skeleton = new THREE.Skeleton(boneList);
const vertexColor = (name) => new THREE.MeshStandardMaterial({ name, vertexColors: true, roughness: 0.65, metalness: 0.05 });
const neon = new THREE.MeshStandardMaterial({
  name: 'NeonGlow',
  color: 0x0a2530,
  emissive: new THREE.Color(0x22e6ff),
  emissiveIntensity: 1,
  roughness: 0.4,
});

function skinned(name, geometry, material) {
  const mesh = new THREE.SkinnedMesh(geometry, material);
  mesh.name = name;
  mesh.bind(skeleton);
  if (geometry.morphAttributes.position) {
    mesh.updateMorphTargets();
    mesh.morphTargetDictionary = Object.fromEntries(Object.keys(morphNames).map((n, i) => [n, i]));
  }
  return mesh;
}
const bodyMesh = skinned('Body', bodyGeometry, vertexColor('BodyMaterial'));
const headMesh = skinned('Wolf3D_Head', headGeometry, vertexColor('HeadMaterial'));
const visorMesh = skinned('Visor', visorGeometry, neon);
const stripMesh = skinned('ChestStrip', stripGeometry, neon);

// ---- animation clips -------------------------------------------------------
const q = (x = 0, y = 0, z = 0) => new THREE.Quaternion().setFromEuler(new THREE.Euler(x, y, z));
/** One quaternion track sampled from fn(phase 0..1) -> Euler [x,y,z]. */
function track(boneName, duration, fn, samples = 16) {
  const times = [];
  const values = [];
  for (let i = 0; i <= samples; i++) {
    const phase = i / samples;
    times.push(phase * duration);
    q(...fn(phase)).toArray(values, values.length);
  }
  return new THREE.QuaternionKeyframeTrack(`${boneName}.quaternion`, times, values);
}
const tau = Math.PI * 2;

function locomotion(name, duration, { swing, knee, armSwing, lean, bob }) {
  const s = (p, offset = 0) => Math.sin((p + offset) * tau);
  const tracks = [];
  for (const [side, offset] of [['Left', 0], ['Right', 0.5]]) {
    tracks.push(
      track(`${side}UpLeg`, duration, (p) => [s(p, offset) * swing, 0, 0]),
      track(`${side}Leg`, duration, (p) => [Math.max(0, -s(p, offset + 0.25)) * knee, 0, 0]),
      track(`${side}Arm`, duration, (p) => [-s(p, offset) * armSwing, 0, side === 'Left' ? 0.1 : -0.1]),
      track(`${side}ForeArm`, duration, (p) => [-0.25 - Math.max(0, s(p, offset + 0.5)) * armSwing * 0.6, 0, 0]),
    );
  }
  tracks.push(
    track('Spine', duration, (p) => [lean + s(p * 2) * 0.02, s(p) * 0.06, 0]),
    new THREE.VectorKeyframeTrack(
      'Hips.position',
      [0, duration / 4, duration / 2, (duration * 3) / 4, duration],
      [0, 0.95, 0, 0, 0.95 - bob, 0, 0, 0.95, 0, 0, 0.95 - bob, 0, 0, 0.95, 0],
    ),
  );
  return new THREE.AnimationClip(name, duration, tracks);
}

const idle = new THREE.AnimationClip('Idle', 3, [
  track('Spine', 3, (p) => [Math.sin(p * tau) * 0.015, 0, 0]),
  track('Chest', 3, (p) => [Math.sin(p * tau + 0.6) * 0.02, 0, 0]),
  track('LeftArm', 3, (p) => [0, 0, 0.12 + Math.sin(p * tau) * 0.01]),
  track('RightArm', 3, (p) => [0, 0, -0.12 - Math.sin(p * tau) * 0.01]),
  track('LeftForeArm', 3, () => [-0.1, 0, 0]),
  track('RightForeArm', 3, () => [-0.1, 0, 0]),
]);
const walk = locomotion('Walk', 1.1, { swing: 0.55, knee: 0.7, armSwing: 0.45, lean: 0.03, bob: 0.025 });
const run = locomotion('Run', 0.62, { swing: 0.95, knee: 1.5, armSwing: 0.9, lean: 0.2, bob: 0.06 });

// ---- export ---------------------------------------------------------------
const scene = new THREE.Scene();
scene.add(hips, bodyMesh, headMesh, visorMesh, stripMesh);

const exporter = new GLTFExporter();
const glb = await exporter.parseAsync(scene, {
  binary: true,
  animations: [idle, walk, run],
  onlyVisible: false,
});

let binary = '';
const bytes = new Uint8Array(glb);
for (let i = 0; i < bytes.length; i += 0x8000) {
  binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
}
window.__glb = btoa(binary);
