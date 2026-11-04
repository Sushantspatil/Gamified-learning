// Renders an orthographic front/side view of a model with a measurement grid,
// so joint positions can be read off in fractions of the model height.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const params = new URLSearchParams(location.search);
const view = params.get('view') ?? 'front';
const url = params.get('model') ?? '/models/meshy-model.glb';
const gltf = await new GLTFLoader().loadAsync(url);
const model = gltf.scene;
model.updateMatrixWorld(true);
const box = new THREE.Box3().setFromObject(model);
const size = box.getSize(new THREE.Vector3());
const center = box.getCenter(new THREE.Vector3());
const H = size.y;
const W = 900, HH = 1000;
const renderer = new THREE.WebGLRenderer({ canvas: document.getElementById('gl'), antialias: true, preserveDrawingBuffer: true });
renderer.setSize(W, HH, false);
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x333333);
model.traverse((o) => { if (o.isMesh) o.material = new THREE.MeshBasicMaterial({ map: o.material.map }); });
scene.add(model);
const viewH = H * 1.1;
const viewW = viewH * (W / HH);
const cam = new THREE.OrthographicCamera(-viewW / 2, viewW / 2, viewH / 2, -viewH / 2, 0.01, 100);
cam.position.set(center.x + (view === 'side' ? 5 : 0), center.y, center.z + (view === 'side' ? 0 : 5));
cam.lookAt(center);
renderer.render(scene, cam);

// grid in fractions of height, origin at the feet and at the model's x/z center
const g = document.getElementById('ov').getContext('2d');
const px = HH / viewH;
const yOf = (f) => HH / 2 - (box.min.y + f * H - center.y) * px;
g.font = '12px sans-serif';
for (let f = 0; f <= 1.0001; f += 0.025) {
  const y = yOf(f);
  const major = Math.abs(f * 10 - Math.round(f * 10)) < 1e-6;
  g.strokeStyle = major ? 'rgba(255,255,0,.7)' : 'rgba(255,255,255,.22)';
  g.beginPath(); g.moveTo(0, y); g.lineTo(W, y); g.stroke();
  g.fillStyle = '#ff0'; g.fillText(f.toFixed(3), 4, y - 2);
}
for (let f = -0.5; f <= 0.5001; f += 0.05) {
  const x = W / 2 + f * H * px;
  const major = Math.abs(f * 10 - Math.round(f * 10)) < 1e-6;
  g.strokeStyle = major ? 'rgba(0,255,255,.7)' : 'rgba(255,255,255,.2)';
  g.beginPath(); g.moveTo(x, 0); g.lineTo(x, HH); g.stroke();
  g.fillStyle = '#0ff'; g.fillText(f.toFixed(2), x + 2, HH - 6);
}
window.__info = { H, min: box.min.toArray(), max: box.max.toArray(), center: center.toArray() };
window.__done = true;
