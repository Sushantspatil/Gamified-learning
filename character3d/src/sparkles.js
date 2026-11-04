import * as THREE from 'three';

let starTexture = null;
function getStarTexture() {
  if (starTexture) return starTexture;
  const size = 64;
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const g = canvas.getContext('2d');
  const c = size / 2;
  // soft round glow...
  const glow = g.createRadialGradient(c, c, 0, c, c, c);
  glow.addColorStop(0, 'rgba(255,255,255,1)');
  glow.addColorStop(0.25, 'rgba(255,255,255,0.55)');
  glow.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = glow;
  g.fillRect(0, 0, size, size);
  // ...with a four-point twinkle on top
  g.fillStyle = 'rgba(255,255,255,0.95)';
  g.beginPath();
  g.moveTo(c, 2);
  g.quadraticCurveTo(c, c, size - 2, c);
  g.quadraticCurveTo(c, c, c, size - 2);
  g.quadraticCurveTo(c, c, 2, c);
  g.quadraticCurveTo(c, c, c, 2);
  g.fill();
  starTexture = new THREE.CanvasTexture(canvas);
  starTexture.colorSpace = THREE.SRGBColorSpace;
  return starTexture;
}

const GOLD = new THREE.Color(0xffd34a);
const WHITE = new THREE.Color(0xffffff);

/**
 * A small pool of twinkling sparkles that burst out of a point and fall back,
 * for cheers and landings. One draw call, no allocation per frame; nothing is
 * drawn while no sparkle is alive.
 */
export class Sparkles {
  #count;
  #positions;
  #colors;
  #velocity;
  #life;
  #maxLife;
  #base; // base colour per particle (rgb)
  #points;
  #geometry;
  #material;
  #next = 0;
  #alive = 0;
  accent = new THREE.Color(0x8b7bff);

  constructor(scene, count = 96) {
    this.#count = count;
    this.#positions = new Float32Array(count * 3);
    this.#colors = new Float32Array(count * 4); // r, g, b and alpha
    this.#velocity = new Float32Array(count * 3);
    this.#life = new Float32Array(count);
    this.#maxLife = new Float32Array(count).fill(1);
    this.#base = new Float32Array(count * 3);
    this.#geometry = new THREE.BufferGeometry();
    this.#geometry.setAttribute('position', new THREE.BufferAttribute(this.#positions, 3));
    this.#geometry.setAttribute('color', new THREE.BufferAttribute(this.#colors, 4));
    this.#material = new THREE.PointsMaterial({
      size: 0.19,
      toneMapped: false,
      map: getStarTexture(),
      vertexColors: true,
      transparent: true,
      depthWrite: false,
      // Normal (not additive) blending with a per-sparkle alpha: additive
      // blending writes alpha onto a transparent canvas and leaves dark dots.
      sizeAttenuation: true,
    });
    this.#points = new THREE.Points(this.#geometry, this.#material);
    this.#points.frustumCulled = false;
    this.#points.visible = false;
    this.#points.renderOrder = 5;
    scene.add(this.#points);
    this.scene = scene;
  }

  /** Emits [n] sparkles from [origin], flying out by about [speed] m/s. */
  burst(origin, { n = 14, speed = 1.6, upward = 1.2, spread = 0.12 } = {}) {
    for (let i = 0; i < n; i++) {
      const k = this.#next;
      this.#next = (this.#next + 1) % this.#count;
      const a = Math.random() * Math.PI * 2;
      const s = speed * (0.4 + Math.random() * 0.8);
      this.#positions[k * 3] = origin.x + Math.cos(a) * spread * Math.random();
      this.#positions[k * 3 + 1] = origin.y + Math.random() * spread;
      this.#positions[k * 3 + 2] = origin.z + Math.sin(a) * spread * Math.random();
      this.#velocity[k * 3] = Math.cos(a) * s;
      this.#velocity[k * 3 + 1] = upward * (0.5 + Math.random());
      this.#velocity[k * 3 + 2] = Math.sin(a) * s * 0.6;
      const pick = Math.random();
      const colour = pick < 0.45 ? GOLD : pick < 0.7 ? WHITE : this.accent;
      this.#base[k * 3] = colour.r;
      this.#base[k * 3 + 1] = colour.g;
      this.#base[k * 3 + 2] = colour.b;
      this.#maxLife[k] = 0.7 + Math.random() * 0.6;
      this.#life[k] = this.#maxLife[k];
    }
    this.#points.visible = true;
  }

  update(dt) {
    if (!this.#points.visible) return;
    let alive = 0;
    for (let k = 0; k < this.#count; k++) {
      if (this.#life[k] <= 0) {
        this.#colors[k * 4 + 3] = 0;
        continue;
      }
      this.#life[k] -= dt;
      alive++;
      this.#velocity[k * 3 + 1] -= 2.4 * dt; // gravity
      this.#positions[k * 3] += this.#velocity[k * 3] * dt;
      this.#positions[k * 3 + 1] += this.#velocity[k * 3 + 1] * dt;
      this.#positions[k * 3 + 2] += this.#velocity[k * 3 + 2] * dt;
      // twinkle, and fade out over the last part of the life
      const t = Math.max(0, this.#life[k] / this.#maxLife[k]);
      const twinkle = 0.7 + 0.3 * Math.sin((this.#life[k] + k) * 38);
      const f = Math.min(1, t * 2.2) * twinkle;
      this.#colors[k * 4] = this.#base[k * 3];
      this.#colors[k * 4 + 1] = this.#base[k * 3 + 1];
      this.#colors[k * 4 + 2] = this.#base[k * 3 + 2];
      this.#colors[k * 4 + 3] = f;
    }
    this.#geometry.attributes.position.needsUpdate = true;
    this.#geometry.attributes.color.needsUpdate = true;
    this.#alive = alive;
    if (alive === 0) this.#points.visible = false;
  }

  get active() {
    return this.#alive > 0 || this.#points.visible;
  }

  dispose() {
    this.scene.remove(this.#points);
    this.#geometry.dispose();
    this.#material.dispose();
  }
}
