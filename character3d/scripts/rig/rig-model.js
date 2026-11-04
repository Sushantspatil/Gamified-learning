// Runs in the browser (see rig-model.mjs). Takes a static, textured character
// mesh and turns it into a rigged character:
//   1. builds a humanoid skeleton from joint landmarks (fractions of height),
//   2. computes skin weights (distance to each bone, side-aware, smoothed
//      across the mesh),
//   3. generates looping Idle, Walk and Run animations,
//   4. exports one .glb with the mesh, skeleton, animations and (downsized)
//      textures.
// The landmarks in JOINTS were measured on the supplied Meshy character; another
// character needs its own numbers (see README).
import * as THREE from 'three';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const params = new URLSearchParams(location.search);
const SOURCE = params.get('model') ?? '/models/meshy-model.glb';
const TEXTURE_SIZE = Number(params.get('tex') ?? 2048);
const HEIGHT = 1.75; // metres: the rigged model is exported at this height

// ---- landmarks: [x, y, z] as fractions of the model height --------------
// x: 0 is the centre line, + is the character's left. y: 0 feet .. 1 top.
// z: + is forward. Left side values; the right side is mirrored in x.
const JOINTS = {
  Hips: [0, 0.445, -0.02],
  Spine: [0, 0.52, -0.025],
  Chest: [0, 0.62, -0.03],
  Neck: [0, 0.735, -0.03],
  Head: [0, 0.775, -0.03],
  UpLeg: [0.07, 0.4, -0.02],
  Leg: [0.085, 0.235, -0.015],
  Foot: [0.1, 0.085, -0.035],
  Toe: [0.105, 0.015, 0.09],
  Arm: [0.125, 0.675, -0.03],
  ForeArm: [0.215, 0.575, 0.02],
  Hand: [0.285, 0.495, 0.055],
  HandTip: [0.335, 0.405, 0.1],
  HeadTop: [0, 0.985, -0.03],
};

// Bones: name, parent, own joint, the line the bone "covers" (for skin
// weights) and a radius (how far its influence reaches). `side` bones only
// affect their own half of the body.
const mirror = (v) => [-v[0], v[1], v[2]];
const BONES = [
  { name: 'Hips', parent: null, joint: JOINTS.Hips, seg: [[0, 0.36, -0.02], [0, 0.5, -0.025]], r: 0.115 },
  { name: 'Spine', parent: 'Hips', joint: JOINTS.Spine, seg: [[0, 0.5, -0.025], [0, 0.6, -0.03]], r: 0.115 },
  { name: 'Chest', parent: 'Spine', joint: JOINTS.Chest, seg: [[0, 0.6, -0.03], [0, 0.72, -0.03]], r: 0.125 },
  { name: 'Neck', parent: 'Chest', joint: JOINTS.Neck, seg: [[0, 0.72, -0.03], [0, 0.78, -0.03]], r: 0.05 },
  { name: 'Head', parent: 'Neck', joint: JOINTS.Head, seg: [JOINTS.Head, JOINTS.HeadTop], r: 0.115 },
];
for (const [side, sign] of [['Left', 1], ['Right', -1]]) {
  const m = (v) => (sign === 1 ? v : mirror(v));
  BONES.push(
    { name: `${side}UpLeg`, parent: 'Hips', joint: m(JOINTS.UpLeg), seg: [m(JOINTS.UpLeg), m(JOINTS.Leg)], r: 0.075, side: sign },
    { name: `${side}Leg`, parent: `${side}UpLeg`, joint: m(JOINTS.Leg), seg: [m(JOINTS.Leg), m(JOINTS.Foot)], r: 0.06, side: sign },
    { name: `${side}Foot`, parent: `${side}Leg`, joint: m(JOINTS.Foot), seg: [m(JOINTS.Foot), m(JOINTS.Toe)], r: 0.065, side: sign },
    { name: `${side}Arm`, parent: 'Chest', joint: m(JOINTS.Arm), seg: [m(JOINTS.Arm), m(JOINTS.ForeArm)], r: 0.05, side: sign },
    { name: `${side}ForeArm`, parent: `${side}Arm`, joint: m(JOINTS.ForeArm), seg: [m(JOINTS.ForeArm), m(JOINTS.Hand)], r: 0.042, side: sign },
    { name: `${side}Hand`, parent: `${side}ForeArm`, joint: m(JOINTS.Hand), seg: [m(JOINTS.Hand), m(JOINTS.HandTip)], r: 0.045, side: sign },
  );
}
const boneIndex = Object.fromEntries(BONES.map((b, i) => [b.name, i]));

// ---- load and normalise the source mesh -----------------------------------
const gltf = await new GLTFLoader().loadAsync(SOURCE);
gltf.scene.updateMatrixWorld(true);
const box = new THREE.Box3().setFromObject(gltf.scene);
const srcHeight = box.max.y - box.min.y;
const centre = box.getCenter(new THREE.Vector3());
const scale = HEIGHT / srcHeight;
// source space -> metres, feet on y=0, centred in x and z
const normalise = new THREE.Matrix4()
  .makeScale(scale, scale, scale)
  .multiply(new THREE.Matrix4().makeTranslation(-centre.x, -box.min.y, -centre.z));

const p = (v) => new THREE.Vector3(v[0] * HEIGHT, v[1] * HEIGHT, v[2] * HEIGHT);

// ---- skeleton ---------------------------------------------------------------
const bones = BONES.map((def) => {
  const bone = new THREE.Bone();
  bone.name = def.name;
  return bone;
});
BONES.forEach((def, i) => {
  const joint = p(def.joint);
  if (def.parent) {
    const parentJoint = p(BONES[boneIndex[def.parent]].joint);
    bones[i].position.copy(joint).sub(parentJoint);
    bones[boneIndex[def.parent]].add(bones[i]);
  } else {
    bones[i].position.copy(joint);
  }
});
bones[0].updateMatrixWorld(true);
const skeleton = new THREE.Skeleton(bones);

// ---- skin weights -----------------------------------------------------------
const smooth = (a, b, x) => {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
};
const segs = BONES.map((b) => [p(b.seg[0]), p(b.seg[1])]);
const tmp = new THREE.Vector3();
const closest = new THREE.Vector3();
function distToSegment(point, [a, b]) {
  const ab = tmp.copy(b).sub(a);
  const t = Math.min(1, Math.max(0, point.clone().sub(a).dot(ab) / ab.lengthSq()));
  closest.copy(a).addScaledVector(ab, t);
  return point.distanceTo(closest);
}

/** Raw (unsmoothed) weights of one point, one value per bone, summing to 1. */
function rawWeights(point) {
  const w = new Float32Array(BONES.length);
  let best = 0;
  let bestScore = Infinity;
  for (let i = 0; i < BONES.length; i++) {
    const def = BONES[i];
    const d = distToSegment(point, segs[i]) / (def.r * HEIGHT);
    // limbs only move their own half of the body
    let side = 1;
    if (def.side === 1) side = smooth(-0.012 * HEIGHT, 0.012 * HEIGHT, point.x);
    if (def.side === -1) side = 1 - smooth(-0.012 * HEIGHT, 0.012 * HEIGHT, point.x);
    if (d < bestScore && side > 0.5) {
      bestScore = d;
      best = i;
    }
    w[i] = d > 3 ? 0 : side / Math.pow(Math.max(d, 0.15), 3.5);
  }
  let sum = 0;
  for (const v of w) sum += v;
  if (sum <= 0) {
    w[best] = 1;
    sum = 1;
  }
  for (let i = 0; i < w.length; i++) w[i] /= sum;

  // everything above the neck (hair, cap, hood top) moves with the head
  const t = smooth(0.745 * HEIGHT, 0.79 * HEIGHT, point.y);
  if (t > 0) {
    for (let i = 0; i < w.length; i++) w[i] *= 1 - t;
    w[boneIndex.Head] += t;
  }
  return w;
}

/**
 * Skin weights for a geometry. Identical positions (UV seams) share one set of
 * weights, and the weights are smoothed along the mesh so joints bend softly.
 */
function skinGeometry(geometry, iterations = 5) {
  const pos = geometry.attributes.position;
  const keyOf = (i) =>
    `${Math.round(pos.getX(i) * 1e4)},${Math.round(pos.getY(i) * 1e4)},${Math.round(pos.getZ(i) * 1e4)}`;
  const unique = new Map();
  const uid = new Int32Array(pos.count);
  const points = [];
  for (let i = 0; i < pos.count; i++) {
    const key = keyOf(i);
    let id = unique.get(key);
    if (id === undefined) {
      id = points.length;
      unique.set(key, id);
      points.push(new THREE.Vector3().fromBufferAttribute(pos, i));
    }
    uid[i] = id;
  }
  const n = points.length;
  const nb = BONES.length;
  let weights = new Float32Array(n * nb);
  points.forEach((pt, id) => weights.set(rawWeights(pt), id * nb));

  // adjacency from triangle edges
  const neighbours = Array.from({ length: n }, () => new Set());
  const index = geometry.index;
  const tri = (a, b, c) => {
    for (const [x, y] of [[a, b], [b, c], [c, a]]) {
      if (x !== y) {
        neighbours[x].add(y);
        neighbours[y].add(x);
      }
    }
  };
  const count = index ? index.count : pos.count;
  for (let i = 0; i < count; i += 3) {
    const at = (k) => uid[index ? index.getX(i + k) : i + k];
    tri(at(0), at(1), at(2));
  }
  for (let it = 0; it < iterations; it++) {
    const next = new Float32Array(weights.length);
    for (let v = 0; v < n; v++) {
      const list = [...neighbours[v]];
      for (let b = 0; b < nb; b++) {
        let avg = 0;
        for (const u of list) avg += weights[u * nb + b];
        avg = list.length ? avg / list.length : weights[v * nb + b];
        next[v * nb + b] = 0.5 * weights[v * nb + b] + 0.5 * avg;
      }
    }
    weights = next;
  }

  // keep the 4 strongest bones per vertex
  const skinIndex = new Uint16Array(pos.count * 4);
  const skinWeight = new Float32Array(pos.count * 4);
  for (let i = 0; i < pos.count; i++) {
    const base = uid[i] * nb;
    const order = Array.from({ length: nb }, (_, b) => b).sort((a, b) => weights[base + b] - weights[base + a]);
    let sum = 0;
    for (let k = 0; k < 4; k++) sum += weights[base + order[k]];
    for (let k = 0; k < 4; k++) {
      skinIndex[i * 4 + k] = order[k];
      skinWeight[i * 4 + k] = sum > 0 ? weights[base + order[k]] / sum : k === 0 ? 1 : 0;
    }
  }
  geometry.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(skinIndex, 4));
  geometry.setAttribute('skinWeight', new THREE.Float32BufferAttribute(skinWeight, 4));
}

// ---- skinned meshes ---------------------------------------------------------
const skinned = [];
gltf.scene.traverse((object) => {
  if (!object.isMesh) return;
  const geometry = object.geometry.clone();
  geometry.applyMatrix4(object.matrixWorld);
  geometry.applyMatrix4(normalise);
  for (const name of Object.keys(geometry.attributes)) {
    if (!['position', 'normal', 'uv'].includes(name)) geometry.deleteAttribute(name);
  }
  skinGeometry(geometry);
  const material = object.material;
  // Keep the texture crisp but small: JPEG at the requested size.
  for (const key of ['map', 'emissiveMap', 'normalMap', 'roughnessMap', 'metalnessMap', 'aoMap']) {
    if (material[key]) material[key].userData.mimeType = key === 'normalMap' ? 'image/png' : 'image/jpeg';
  }
  if (material.metalness !== undefined && !material.metalnessMap) material.metalness = Math.min(material.metalness, 0.1);
  const mesh = new THREE.SkinnedMesh(geometry, material);
  mesh.name = object.name || 'Character';
  mesh.frustumCulled = false;
  skinned.push(mesh);
});
const root = new THREE.Group();
root.name = 'CharacterRig';
root.add(bones[0], ...skinned);
root.updateMatrixWorld(true);
skinned.forEach((mesh) => mesh.bind(skeleton));

// ---- animation --------------------------------------------------------------
const TAU = Math.PI * 2;
const euler = new THREE.Euler();
const quat = (x = 0, y = 0, z = 0) => new THREE.Quaternion().setFromEuler(euler.set(x, y, z, 'YXZ'));
const SAMPLES = 24;

/** Rotation track sampled from fn(phase 0..1) -> [x, y, z] radians. */
function rotation(bone, duration, fn) {
  const times = [];
  const values = [];
  for (let i = 0; i <= SAMPLES; i++) {
    const phase = i / SAMPLES;
    times.push(phase * duration);
    quat(...fn(phase)).toArray(values, values.length);
  }
  return new THREE.QuaternionKeyframeTrack(`${bone}.quaternion`, times, values);
}

const hipsHome = p(JOINTS.Hips);
function hipsPosition(duration, fn) {
  const times = [];
  const values = [];
  for (let i = 0; i <= SAMPLES; i++) {
    const phase = i / SAMPLES;
    times.push(phase * duration);
    values.push(hipsHome.x + fn(phase)[0], hipsHome.y + fn(phase)[1], hipsHome.z);
  }
  return new THREE.VectorKeyframeTrack('Hips.position', times, values);
}

/**
 * A looping gait. Angles are radians about the X axis: negative swings a limb
 * forward, positive backward (the character faces +Z).
 */
function gait(name, duration, g) {
  const s = (phase, off = 0) => Math.sin((phase + off) * TAU);
  const c = (phase, off = 0) => Math.cos((phase + off) * TAU);
  const tracks = [];
  for (const [side, off, sign] of [['Left', 0, 1], ['Right', 0.5, -1]]) {
    const hip = (ph) => -g.hip * s(ph, off);
    const knee = (ph) => g.knee * Math.max(0, c(ph, off)) ** 1.2 + g.kneeBase;
    tracks.push(
      rotation(`${side}UpLeg`, duration, (ph) => [hip(ph), 0, 0]),
      rotation(`${side}Leg`, duration, (ph) => [knee(ph), 0, 0]),
      rotation(`${side}Foot`, duration, (ph) => [-(hip(ph) + knee(ph)) * 0.65 + g.toeOff * Math.max(0, -s(ph, off + 0.25)), 0, 0]),
      // arms: lowered from the A-pose, swing opposite to the leg on their side
      rotation(`${side}Arm`, duration, (ph) => {
        const swing = g.arm * s(ph, off);
        return [swing, 0, -sign * g.armDown];
      }),
      rotation(`${side}ForeArm`, duration, (ph) => [-g.elbow - 0.2 * Math.max(0, -s(ph, off)) * (g.arm / 0.4), 0, 0]),
      rotation(`${side}Hand`, duration, () => [-0.1, 0, 0]),
    );
  }
  tracks.push(
    // hips drop when both feet are down (legs spread) and rise at mid-stance
    hipsPosition(duration, (ph) => [g.sway * s(ph), g.bob * (c(ph * 2) - 1)]),
    rotation('Hips', duration, (ph) => [g.lean * 0.4, g.twist * s(ph), g.roll * s(ph)]),
    rotation('Spine', duration, (ph) => [g.lean * 0.4 + 0.015 * s(ph * 2), -g.twist * 0.7 * s(ph), -g.roll * 0.5 * s(ph)]),
    rotation('Chest', duration, (ph) => [g.lean * 0.3, -g.twist * 0.5 * s(ph), 0]),
    rotation('Neck', duration, (ph) => [-g.lean * 0.5, 0, 0]),
    rotation('Head', duration, (ph) => [-g.lean * 0.4 + 0.01 * s(ph * 2), g.twist * 0.6 * s(ph), 0]),
  );
  return new THREE.AnimationClip(name, duration, tracks);
}

// Ground speed of a gait = stride / duration, with leg length 0.55 m:
//   Walk: stride ~1.05 m in 0.8 s  -> ~1.3 m/s   (WALK_SPEED in locomotionLogic.js)
//   Run:  stride ~1.7 m in 0.52 s  -> ~3.3 m/s   (RUN_SPEED)
const walk = gait('Walk', 0.8, {
  hip: 0.5, knee: 0.95, kneeBase: 0.06, toeOff: 0.5,
  arm: 0.35, armDown: 0.3, elbow: 0.25,
  bob: 0.034, sway: 0.008, lean: 0.04, twist: 0.09, roll: 0.03,
});
const run = gait('Run', 0.52, {
  hip: 0.8, knee: 1.55, kneeBase: 0.1, toeOff: 0.9,
  arm: 0.7, armDown: 0.36, elbow: 1.2,
  bob: 0.04, sway: 0.01, lean: 0.2, twist: 0.2, roll: 0.05,
});

const idleDuration = 3.2;
const idleTracks = [
  rotation('Spine', idleDuration, (ph) => [0.012 * Math.sin(ph * TAU), 0, 0]),
  rotation('Chest', idleDuration, (ph) => [0.018 * Math.sin(ph * TAU + 0.6), 0, 0]),
  rotation('Head', idleDuration, (ph) => [0.01 * Math.sin(ph * TAU + 1.2), 0.03 * Math.sin(ph * TAU), 0]),
  hipsPosition(idleDuration, (ph) => [0, -0.004 * (1 - Math.cos(ph * TAU))]),
];
for (const [side, sign] of [['Left', 1], ['Right', -1]]) {
  idleTracks.push(
    rotation(`${side}Arm`, idleDuration, (ph) => [0.01 * Math.sin(ph * TAU + 0.4), 0, -sign * (0.34 + 0.015 * Math.sin(ph * TAU))]),
    rotation(`${side}ForeArm`, idleDuration, () => [-0.18, 0, 0]),
    rotation(`${side}Hand`, idleDuration, () => [-0.08, 0, 0]),
  );
}
const idle = new THREE.AnimationClip('Idle', idleDuration, idleTracks);

// ---- export -----------------------------------------------------------------
window.__rig = { bones, skeleton, root, clips: [idle, walk, run], height: HEIGHT };
const glb = await new GLTFExporter().parseAsync(root, {
  binary: true,
  animations: [idle, walk, run],
  maxTextureSize: TEXTURE_SIZE,
  onlyVisible: false,
});
let binary = '';
const bytes = new Uint8Array(glb);
for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
window.__glb = btoa(binary);
window.__done = true;
