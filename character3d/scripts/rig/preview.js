// Contact sheet: one clip at several moments of its cycle, seen from the side
// (top row) and the front (bottom row). Used to check the rig by eye.
//   ?model=/models/character.glb&clip=Walk
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const params = new URLSearchParams(location.search);
const url = params.get('model') ?? '/models/character.glb';
const clipName = params.get('clip') ?? 'Walk';
const cols = Number(params.get('cols') ?? 6);
const gltf = await new GLTFLoader().loadAsync(url);
const model = gltf.scene;
model.traverse((o) => { if (o.isMesh) { o.material = new THREE.MeshBasicMaterial({ map: o.material.map }); o.frustumCulled = false; } });
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x303030);
scene.add(model);
const mixer = new THREE.AnimationMixer(model);
const clip = gltf.animations.find((c) => c.name === clipName);
const action = mixer.clipAction(clip);
action.play();

const canvas = document.getElementById('c');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, preserveDrawingBuffer: true });
renderer.setSize(canvas.width, canvas.height, false);
renderer.setScissorTest(true);
const tw = canvas.width / cols, th = canvas.height / 2;
const half = 1.05;
const cams = ['side', 'front'].map((v) => {
  const c = new THREE.OrthographicCamera(-half * (tw / th), half * (tw / th), half + 0.1, -half + 0.1, 0.1, 50);
  c.position.set(v === 'side' ? 5 : 0, 0.9, v === 'side' ? 0 : 5);
  c.lookAt(0, 0.9, 0);
  return c;
});
for (let i = 0; i < cols; i++) {
  mixer.setTime((i / cols) * clip.duration);
  model.updateMatrixWorld(true);
  cams.forEach((cam, row) => {
    const x = i * tw, y = (1 - row - 1 + 1) * 0 + (row === 0 ? th : 0);
    renderer.setViewport(x, y, tw, th);
    renderer.setScissor(x, y, tw, th);
    renderer.render(scene, cam);
  });
}
window.__info = { clip: clip.name, duration: clip.duration };
window.__done = true;
