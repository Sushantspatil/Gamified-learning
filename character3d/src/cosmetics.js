import * as THREE from 'three';

/** Colour of each profile frame (a glowing ring on the floor). */
export const FRAME_COLORS = {
  bronze: 0xcd7f32,
  silver: 0xc9d6ea,
  gold: 0xffc83a,
};

/** Colour of each avatar's floating emblem. */
export const AVATAR_COLORS = {
  scholar: 0x8b7bff,
  explorer: 0x22d3ee,
  champion: 0xffc83a,
  genius: 0xf07cf8,
};

let ringTexture = null;
function getRingTexture() {
  if (ringTexture) return ringTexture;
  const size = 256;
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const g = canvas.getContext('2d');
  const c = size / 2;
  const gradient = g.createRadialGradient(c, c, 0, c, c, c);
  // transparent middle, a bright thin ring near 78% of the radius, soft falloff
  gradient.addColorStop(0, 'rgba(255,255,255,0)');
  gradient.addColorStop(0.55, 'rgba(255,255,255,0.04)');
  gradient.addColorStop(0.72, 'rgba(255,255,255,0.55)');
  gradient.addColorStop(0.78, 'rgba(255,255,255,1)');
  gradient.addColorStop(0.84, 'rgba(255,255,255,0.55)');
  gradient.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gradient;
  g.fillRect(0, 0, size, size);
  ringTexture = new THREE.CanvasTexture(canvas);
  ringTexture.colorSpace = THREE.SRGBColorSpace;
  return ringTexture;
}

/**
 * A glowing ring on the floor around the feet, in the colour of the equipped
 * profile frame. `update(t)` pulses it gently.
 */
export function createFrameRing(frame) {
  const color = FRAME_COLORS[frame];
  if (color === undefined) return null;
  const material = new THREE.MeshBasicMaterial({
    map: getRingTexture(),
    color,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    opacity: 0.85,
  });
  const ring = new THREE.Mesh(new THREE.PlaneGeometry(1.7, 1.7).rotateX(-Math.PI / 2), material);
  ring.renderOrder = -1;
  ring.userData.update = (t) => {
    const pulse = 1 + 0.035 * Math.sin(t * 2.2);
    ring.scale.setScalar(pulse);
    material.opacity = 0.72 + 0.18 * Math.sin(t * 2.2);
  };
  return ring;
}

function glow(color, intensity = 1.1) {
  return new THREE.MeshStandardMaterial({
    color,
    emissive: color,
    emissiveIntensity: intensity,
    roughness: 0.4,
    metalness: 0.25,
  });
}

/**
 * A small emblem that floats above the head for the equipped avatar:
 * scholar = open book, explorer = compass, champion = crown, genius = light bulb.
 * Built from primitives so it needs no files. `update(t)` spins and bobs it.
 */
export function createEmblem(avatar) {
  const color = AVATAR_COLORS[avatar];
  if (color === undefined) return null;
  const root = new THREE.Group();
  const body = new THREE.Group();
  root.add(body);
  const mat = glow(color);

  switch (avatar) {
    case 'scholar': {
      for (const sign of [-1, 1]) {
        const page = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.012, 0.14), mat);
        page.position.set(sign * 0.045, 0, 0);
        page.rotation.z = -sign * 0.42;
        body.add(page);
      }
      const spine = new THREE.Mesh(new THREE.BoxGeometry(0.012, 0.016, 0.145), glow(0xffffff, 0.6));
      body.add(spine);
      body.rotation.x = 0.35;
      break;
    }
    case 'explorer': {
      body.add(new THREE.Mesh(new THREE.TorusGeometry(0.075, 0.011, 10, 36), mat));
      const needle = new THREE.Mesh(new THREE.ConeGeometry(0.02, 0.11, 8), glow(0xffffff, 0.8));
      needle.rotation.z = -0.6;
      body.add(needle);
      const tail = new THREE.Mesh(new THREE.ConeGeometry(0.02, 0.1, 8), mat);
      tail.rotation.z = Math.PI - 0.6;
      body.add(tail);
      break;
    }
    case 'champion': {
      body.add(new THREE.Mesh(new THREE.TorusGeometry(0.06, 0.012, 8, 24).rotateX(Math.PI / 2), mat));
      for (let i = 0; i < 5; i++) {
        const a = (i / 5) * Math.PI * 2;
        const spike = new THREE.Mesh(new THREE.ConeGeometry(0.018, 0.075, 6), mat);
        spike.position.set(Math.cos(a) * 0.06, 0.04, Math.sin(a) * 0.06);
        body.add(spike);
        const tip = new THREE.Mesh(new THREE.SphereGeometry(0.01, 8, 8), glow(0xffffff, 0.9));
        tip.position.set(Math.cos(a) * 0.06, 0.085, Math.sin(a) * 0.06);
        body.add(tip);
      }
      break;
    }
    case 'genius': {
      const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.058, 20, 16), glow(color, 1.5));
      bulb.position.y = 0.025;
      body.add(bulb);
      const base = new THREE.Mesh(new THREE.CylinderGeometry(0.028, 0.024, 0.045, 14), glow(0xb8b8c8, 0.15));
      base.position.y = -0.045;
      body.add(base);
      break;
    }
    default:
      return null;
  }

  root.userData.update = (t) => {
    body.rotation.y = t * 1.1;
    body.position.y = 0.012 * Math.sin(t * 2);
  };
  return root;
}
