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
  Shoulder: [0.055, 0.685, -0.03],
  Arm: [0.125, 0.675, -0.03],
  Ball: [0.105, 0.03, 0.045],
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
    { name: `${side}Foot`, parent: `${side}Leg`, joint: m(JOINTS.Foot), seg: [m(JOINTS.Foot), m(JOINTS.Ball)], r: 0.065, side: sign },
    { name: `${side}Toe`, parent: `${side}Foot`, joint: m(JOINTS.Ball), seg: [m(JOINTS.Ball), m(JOINTS.Toe)], r: 0.05, side: sign },
    { name: `${side}Shoulder`, parent: 'Chest', joint: m(JOINTS.Shoulder), seg: [[sign * 0.025, 0.69, -0.03], m(JOINTS.Arm)], r: 0.055, side: sign },
    { name: `${side}Arm`, parent: `${side}Shoulder`, joint: m(JOINTS.Arm), seg: [m(JOINTS.Arm), m(JOINTS.ForeArm)], r: 0.05, side: sign },
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

// ---- arm geometry (also used to keep the hands rigid when skinning) ----
const V3 = (x, y, z) => new THREE.Vector3(x, y, z);
const armRig = Object.fromEntries(
  [1, -1].map((sign) => {
    const m = (v) => p(sign === 1 ? v : mirror(v));
    const S = m(JOINTS.Arm);
    const E = m(JOINTS.ForeArm);
    const W = m(JOINTS.Hand);
    const T = m(JOINTS.HandTip);
    return [
      sign,
      {
        S,
        E,
        W,
        L1: S.distanceTo(E),
        L2: E.distanceTo(W),
        u0: E.clone().sub(S).normalize(),
        f0: W.clone().sub(E).normalize(),
        h0: T.clone().sub(W).normalize(),
      },
    ];
  }),
);


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

  // Hands: anything at or past the wrist plane (fingers, thumb, the glove) moves
  // with the Hand bone alone. Blending it with the forearm is what stretched the
  // thumb and left a ragged cuff when the hand turned.
  for (const sign of [1, -1]) {
    const handIndex = boneIndex[(sign === 1 ? 'Left' : 'Right') + 'Hand'];
    const reach = distToSegment(point, segs[handIndex]) / (BONES[handIndex].r * HEIGHT);
    const onSide = sign === 1 ? smooth(-0.012 * HEIGHT, 0.012 * HEIGHT, point.x) : 1 - smooth(-0.012 * HEIGHT, 0.012 * HEIGHT, point.x);
    if (reach > 2.4 || onSide < 0.5) continue;
    const rig = armRig[sign];
    const wrist = rig.S.clone().add(rig.E.clone().sub(rig.S)).add(rig.W.clone().sub(rig.E));
    const past = point.clone().sub(wrist).dot(rig.f0); // metres beyond the wrist plane
    const lock = smooth(-0.042 * HEIGHT, 0.022 * HEIGHT, past) * (1 - smooth(1.6, 2.4, reach));
    if (lock <= 0) continue;
    for (let i = 0; i < w.length; i++) w[i] *= 1 - lock;
    w[handIndex] += lock;
  }

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
function skinGeometry(geometry, iterations = 10) {
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
    const r = fn(phase);
    (r.isQuaternion ? r : quat(...r)).toArray(values, values.length);
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
      // the toes bend as the heel lifts for push-off
      rotation(`${side}Toe`, duration, (ph) => [-g.toeBend * Math.max(0, -s(ph, off)) + 0.1 * Math.max(0, s(ph, off)), 0, 0]),
      rotation(`${side}Shoulder`, duration, (ph) => [0, 0, 0]),
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
//   Walk: stride ~1.05 m in 0.8 s  -> ~1.3 m/s   (DEFAULT_SPEEDS in locomotionLogic.js)
//   Run:  stride ~1.7 m in 0.52 s  -> ~3.3 m/s
const walk = gait('Walk', 0.8, {
  hip: 0.5, knee: 0.95, kneeBase: 0.06, toeOff: 0.5, toeBend: 0.5,
  arm: 0.35, armDown: 0.3, elbow: 0.25,
  bob: 0.034, sway: 0.008, lean: 0.04, twist: 0.09, roll: 0.03,
});
const run = gait('Run', 0.52, {
  hip: 0.8, knee: 1.55, kneeBase: 0.1, toeOff: 0.9, toeBend: 0.7,
  arm: 0.7, armDown: 0.36, elbow: 1.2,
  bob: 0.04, sway: 0.01, lean: 0.2, twist: 0.2, roll: 0.05,
});

// ---- poses and one-shot actions ---------------------------------------------
// Every action describes the TARGET pose at full strength for the bones it
// uses; all other bones sit in the relaxed idle pose. One-shot actions ease in
// from, and back out to, that relaxed pose, so they join Idle seamlessly.
const smoothstep = (a, b, x) => {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
};
const envelope = (ph, inT, outT) => smoothstep(0, inT, ph) * (1 - smoothstep(1 - outT, 1, ph));
const sn = (ph, times = 1, off = 0) => Math.sin((ph * times + off) * TAU);
const toQ = (r) => (r.isQuaternion ? r : quat(...r));

const CENTRE_BONES = ['Hips', 'Spine', 'Chest', 'Neck', 'Head'];
const SIDE_BONES = ['Shoulder', 'Arm', 'ForeArm', 'Hand', 'UpLeg', 'Leg', 'Foot', 'Toe'];
const REST = {
  Arm: (sign) => [0, 0, -sign * 0.34],
  ForeArm: () => [-0.18, 0, 0],
  Hand: () => [-0.08, 0, 0],
};

// ---- two-bone arm IK ---------------------------------------------------------
// Puts the wrist at a chosen point, so poses like "hand to chin" or "hands
// together" are stated as where the hands go, not as guessed angles. Positions
// are fractions of the height in LEFT-arm space (x > 0 outward); the right arm
// is mirrored automatically.
/** Returns { Arm, ForeArm, Hand } quaternions that put the wrist at `wrist`. */
function armIK(sign, { wrist, pole, handDir, twist = 0 }) {
  const rig = armRig[sign];
  const mir = (a) => V3(a[0] * sign, a[1], a[2]);
  const target = mir(wrist).multiplyScalar(HEIGHT);
  const d = target.clone().sub(rig.S);
  const dist = Math.min(Math.max(d.length(), 0.06), rig.L1 + rig.L2 - 1e-3);
  const dir = d.normalize();
  const along = (rig.L1 * rig.L1 - rig.L2 * rig.L2 + dist * dist) / (2 * dist);
  const height = Math.sqrt(Math.max(0, rig.L1 * rig.L1 - along * along));
  const hint = mir(pole).normalize();
  const side = hint.sub(dir.clone().multiplyScalar(hint.dot(dir))).normalize();
  const elbow = rig.S.clone().addScaledVector(dir, along).addScaledVector(side, height);
  const wristAt = rig.S.clone().addScaledVector(dir, dist);

  const qArm = new THREE.Quaternion().setFromUnitVectors(rig.u0, elbow.clone().sub(rig.S).normalize());
  const foreWorld = new THREE.Quaternion().setFromUnitVectors(rig.f0, wristAt.clone().sub(elbow).normalize());
  // Roll the forearm by half of `twist` and the hand by all of it (about the
  // limb's own axis), so the palm turns without a candy-wrapper at the wrist.
  const foreAxis = wristAt.clone().sub(elbow).normalize();
  const foreTwisted = new THREE.Quaternion().setFromAxisAngle(foreAxis, twist * 0.5 * sign).multiply(foreWorld);
  const qFore = qArm.clone().invert().multiply(foreTwisted);
  const handDirV = mir(handDir).normalize();
  const handWorld = new THREE.Quaternion()
    .setFromAxisAngle(handDirV, twist * sign)
    .multiply(new THREE.Quaternion().setFromUnitVectors(rig.h0, handDirV));
  const qHand = foreTwisted.clone().invert().multiply(handWorld);
  return { Arm: qArm, ForeArm: qFore, Hand: qHand };
}

/**
 * Builds over.Arm / ForeArm / Hand target functions from one description:
 * `arms(ph, sign)` returns an IK goal, or null to leave that arm relaxed.
 */
function armTargets(arms) {
  const cache = new Map();
  const pose = (ph, sign) => {
    const key = `${ph}|${sign}`;
    if (!cache.has(key)) {
      const goal = arms(ph, sign);
      cache.set(key, goal ? armIK(sign, goal) : null);
    }
    return cache.get(key);
  };
  const pick = (bone) => (ph, sign) => pose(ph, sign)?.[bone] ?? toQ(REST[bone](sign));
  return { Arm: pick('Arm'), ForeArm: pick('ForeArm'), Hand: pick('Hand') };
}

/**
 * @param over  per-bone target functions: centre bones fn(ph), side bones
 *              fn(ph, sign) with sign +1 left / -1 right; each returns an
 *              [x, y, z] Euler triple or a Quaternion. `lift(ph)` raises the hips (metres).
 * @param direct bones (names without Left/Right) whose `over` function already
 *              returns the final rotation, so the action does not blend them.
 */
function action(
  name,
  duration,
  { loop = false, inT = 0.15, outT = 0.2, over = {}, lift, direct = [] } = {},
) {
  const e = (ph) => (loop ? 1 : envelope(ph, inT, outT));
  const tracks = [];
  const identity = new THREE.Quaternion();
  for (const bone of CENTRE_BONES) {
    const target = over[bone];
    tracks.push(
      rotation(bone, duration, (ph) =>
        target ? identity.clone().slerp(toQ(target(ph)), e(ph)) : identity.clone(),
      ),
    );
  }
  for (const [side, sign] of [['Left', 1], ['Right', -1]]) {
    for (const base of SIDE_BONES) {
      const rest = toQ(REST[base]?.(sign) ?? [0, 0, 0]);
      const target = over[base];
      // A bone listed in `direct` is given its final rotation at every moment
      // (the action blends it from the relaxed pose itself); the others are
      // blended from the relaxed pose by the action's in/out envelope.
      tracks.push(
        rotation(`${side}${base}`, duration, (ph) =>
          !target
            ? rest.clone()
            : direct.includes(base)
              ? toQ(target(ph, sign)).clone()
              : rest.clone().slerp(toQ(target(ph, sign)), e(ph)),
        ),
      );
    }
  }
  tracks.push(hipsPosition(duration, (ph) => [0, lift ? lift(ph) * e(ph) : 0]));
  return new THREE.AnimationClip(name, duration, tracks);
}

/**
 * Palm to the viewer when the right hand is raised (radians; tuned by eye by
 * rendering the whole wave at the card's size). The first value (1.2) showed
 * the BACK of the glove; half a turn the other way showed the palm but it
 * still turned edge-on during the swing; this value keeps the open palm
 * facing the viewer through the whole wave.
 */
const WAVE_TWIST = 1.2 - Math.PI - 1.4;

const idle = action('Idle', 3.2, {
  loop: true,
  over: {
    Spine: (ph) => [0.012 * sn(ph), 0, 0],
    Chest: (ph) => [0.018 * sn(ph, 1, 0.1), 0, 0],
    Head: (ph) => [0.01 * sn(ph, 1, 0.2), 0.03 * sn(ph), 0],
    Arm: (ph, sign) => [0.01 * sn(ph, 1, 0.07), 0, -sign * (0.34 + 0.015 * sn(ph))],
  },
  lift: (ph) => -0.004 * (1 - Math.cos(ph * TAU)),
});

// A friendly "hi". The right hand travels up in front of the body (elbow
// bending as it comes) to beside the head, palm to the viewer, then rocks from
// side to side about three times. The same path is retraced going down. The
// hand trails the forearm and flicks further over at each end of a swing
// (overlapping action). Held out wide with a high elbow it reads as "go", and
// letting each bone turn by the shortest route sends the arm out to the side
// on the way up, so the hand's path is stated explicitly and solved with IK.
const REST_WRIST = [0.285, 0.495, 0.055]; // the relaxed hand (left-arm space)
const REST_HAND_DIR = [0.05, -0.09, 0.045];
const WAVE_VIA = [0.15, 0.62, 0.17]; // in front of the chest, on the way up
const lerp3 = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
const bezier3 = (a, b, c, t) =>
  a.map((v, i) => (1 - t) * (1 - t) * v + 2 * (1 - t) * t * b[i] + t * t * c[i]);

const wavePoses = new Map();
function wavePose(ph, sign) {
  const key = `${ph}|${sign}`;
  if (wavePoses.has(key)) return wavePoses.get(key);
  const restPose = {
    Arm: toQ(REST.Arm(sign)),
    ForeArm: toQ(REST.ForeArm(sign)),
    Hand: toQ(REST.Hand(sign)),
  };
  let pose = restPose;
  if (sign === -1) {
    const e = envelope(ph, 0.2, 0.22); // how far up the arm is, 0..1
    const swing = smoothstep(0.55, 1, e); // the rocking only once it is up
    // Out from the head (so it never touches the cap) and a little lower: the
    // forearm rocks about 25 degrees each way and the hand follows.
    const up = [0.245 + 0.05 * sn(ph, 3) * swing, 0.805 - 0.012 * Math.abs(sn(ph, 3)) * swing, 0.1];
    const goal = {
      wrist: bezier3(REST_WRIST, WAVE_VIA, up, e),
      pole: lerp3([0.4, -0.6, -0.6], [0.35, -1, 0.05], e),
      // The hand tips only a little, so the open palm stays in view (tipped
      // far it folds into a fist-like shape).
      handDir: lerp3(REST_HAND_DIR, [0.42 * sn(ph, 3, -0.2) * swing, 1, 0.15], e),
      twist: WAVE_TWIST * smoothstep(0.1, 0.8, e),
    };
    const ik = armIK(sign, goal);
    // Join the relaxed pose smoothly at the very start and end.
    const w = smoothstep(0, 0.18, e);
    pose = {
      Arm: restPose.Arm.clone().slerp(ik.Arm, w),
      ForeArm: restPose.ForeArm.clone().slerp(ik.ForeArm, w),
      Hand: restPose.Hand.clone().slerp(ik.Hand, w),
    };
  }
  wavePoses.set(key, pose);
  return pose;
}
const wave = action('Wave', 2.8, {
  inT: 0.2,
  outT: 0.22,
  direct: ['Arm', 'ForeArm', 'Hand'],
  over: {
    Spine: () => [0, 0, 0.03],
    // The head tips towards the waving hand and bobs with each wave.
    Head: (ph) => [-0.02 + 0.015 * sn(ph, 3, 0.25), 0.1, 0.07 + 0.025 * sn(ph, 3)],
    Shoulder: (ph, sign) => (sign === -1 ? [0, 0, -0.1] : [0, 0, 0]),
    Arm: (ph, sign) => wavePose(ph, sign).Arm,
    ForeArm: (ph, sign) => wavePose(ph, sign).ForeArm,
    Hand: (ph, sign) => wavePose(ph, sign).Hand,
  },
});

// Both arms up, two jumps: a victory cheer.
const cheerUp = (ph) => Math.abs(Math.sin(ph * TAU * 2));
const cheerArms = armTargets((ph) => ({
  wrist: [0.2 + 0.01 * sn(ph, 2), 0.94 + 0.01 * cheerUp(ph), 0.0],
  pole: [1, -0.1, -0.35],
  handDir: [0.2, 1, 0],
}));
const cheer = action('Cheer', 1.8, {
  inT: 0.12,
  outT: 0.2,
  lift: (ph) => 0.15 * cheerUp(ph),
  over: {
    Chest: () => [-0.1, 0, 0],
    Head: () => [-0.2, 0, 0],
    Shoulder: (ph, sign) => [0, 0, sign * 0.2],
    UpLeg: (ph) => [-0.5 * cheerUp(ph), 0, 0],
    Leg: (ph) => [0.9 * cheerUp(ph), 0, 0],
    Foot: (ph) => [-0.2 * cheerUp(ph), 0, 0],
    ...cheerArms,
  },
});

// Head down, shoulders low: a disappointed stance, with slow breathing.
const sad = action('Sad', 3.6, {
  loop: true,
  lift: (ph) => -0.016 + 0.004 * sn(ph),
  over: {
    Spine: (ph) => [0.12 + 0.01 * sn(ph), 0, 0],
    Chest: (ph) => [0.18 + 0.015 * sn(ph, 1, 0.1), 0, 0],
    Neck: () => [0.18, 0, 0],
    Head: (ph) => [0.4, 0.05 * sn(ph), 0.05],
    Shoulder: (ph, sign) => [0, 0, -sign * 0.12],
    Arm: (ph, sign) => [0.08, 0, -sign * 0.14],
    ForeArm: () => [-0.12, 0, 0],
    Hand: () => [0.1, 0, 0],
  },
});

// Right hand to the chin while thinking, left arm folded under the elbow.
const thinkArms = armTargets((ph, sign) =>
  sign === -1
    ? { wrist: [0.045, 0.7, 0.11 + 0.004 * sn(ph)], pole: [0.5, -1, 0.1], handDir: [-0.2, 1, 0.45] }
    : { wrist: [0.0, 0.575, 0.115], pole: [0.8, -1, -0.1], handDir: [-1, 0.2, 0.2] },
);
const think = action('Think', 3.6, {
  loop: true,
  over: {
    Spine: (ph) => [0.02, 0.05 * sn(ph), 0.03],
    Head: (ph) => [-0.06, 0.12 * sn(ph), -0.1],
    ...thinkArms,
  },
});

// Applause: hands meet in front of the chest.
const clapPhase = (ph) => 0.5 + 0.5 * Math.sin(ph * TAU * 5);
const clapArms = armTargets((ph) => ({
  wrist: [0.018 + 0.1 * (1 - clapPhase(ph)), 0.64, 0.14],
  pole: [0.8, -1, -0.15],
  handDir: [-0.15, 1, 0.5],
}));
const clap = action('Clap', 1.7, {
  inT: 0.16,
  outT: 0.2,
  over: {
    Head: (ph) => [0.08 * clapPhase(ph), 0, 0],
    ...clapArms,
  },
});

// A relaxed look to the left, then the right.
const lookAround = action('LookAround', 3.6, {
  inT: 0.16,
  outT: 0.16,
  over: {
    Hips: (ph) => [0, 0.05 * sn(ph), 0],
    Spine: (ph) => [0, 0.08 * sn(ph), 0],
    Chest: (ph) => [0, 0.1 * sn(ph), 0],
    Neck: (ph) => [0, 0.25 * sn(ph), 0],
    Head: (ph) => [0.02 * sn(ph, 2), 0.7 * sn(ph), 0],
  },
});

const allClips = [idle, walk, run, wave, cheer, sad, think, clap, lookAround];


// ---- export -----------------------------------------------------------------
window.__rig = { bones, skeleton, root, clips: allClips, height: HEIGHT };
const glb = await new GLTFExporter().parseAsync(root, {
  binary: true,
  animations: allClips,
  maxTextureSize: TEXTURE_SIZE,
  onlyVisible: false,
});
let binary = '';
const bytes = new Uint8Array(glb);
for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
window.__glb = btoa(binary);
window.__done = true;
