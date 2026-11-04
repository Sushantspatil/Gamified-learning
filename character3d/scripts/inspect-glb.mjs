// Prints what a .glb contains, so you can see whether it meets the avatar spec.
//   node scripts/inspect-glb.mjs public/models/your-file.glb
import { readFileSync } from 'node:fs';

const file = process.argv[2];
if (!file) throw new Error('usage: node scripts/inspect-glb.mjs <file.glb>');
const buf = readFileSync(file);
if (buf.toString('utf8', 0, 4) !== 'glTF') throw new Error('not a .glb file');
const jsonLength = buf.readUInt32LE(12);
const json = JSON.parse(buf.toString('utf8', 20, 20 + jsonLength));

const names = (list) => (list ?? []).map((x, i) => x.name ?? `#${i}`);
console.log(`file        ${file} (${(buf.length / 1048576).toFixed(1)} MB)`);
console.log(`generator   ${json.asset?.generator ?? '?'}`);
console.log(`extensions  ${(json.extensionsUsed ?? []).join(', ') || 'none'}`);
console.log(`meshes      ${json.meshes?.length ?? 0}`);
let verts = 0;
const morphs = new Set();
for (const mesh of json.meshes ?? []) {
  for (const p of mesh.primitives) {
    verts += json.accessors[p.attributes.POSITION].count;
  }
  (mesh.extras?.targetNames ?? []).forEach((n) => morphs.add(n));
}
console.log(`vertices    ${verts.toLocaleString()}`);
console.log(`skins       ${json.skins?.length ?? 0}${json.skins ? ` (${json.skins[0].joints.length} joints)` : ''}`);
if (json.skins) {
  const joints = json.skins[0].joints.map((j) => json.nodes[j].name);
  console.log(`joint names ${joints.slice(0, 40).join(', ')}${joints.length > 40 ? ', …' : ''}`);
}
console.log(`animations  ${json.animations?.length ?? 0}: ${names(json.animations).join(', ') || 'none'}`);
console.log(`morph targets ${morphs.size}: ${[...morphs].join(', ') || 'none'}`);
console.log(`materials   ${names(json.materials).join(', ')}`);
console.log(`textures    ${json.textures?.length ?? 0}, images ${json.images?.length ?? 0}`);
