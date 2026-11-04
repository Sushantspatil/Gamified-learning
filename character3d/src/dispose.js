/** Frees GPU memory held by a material, including every texture it uses. */
export function disposeMaterial(material) {
  if (!material) return;
  for (const value of Object.values(material)) {
    if (value && value.isTexture) disposeTexture(value);
  }
  material.dispose();
}

export function disposeTexture(texture) {
  // Textures decoded from a GLB are often ImageBitmaps: close them too.
  if (typeof texture.image?.close === 'function') {
    try {
      texture.image.close();
    } catch {
      /* already closed */
    }
  }
  texture.dispose();
}

/** Disposes every geometry, material, texture and skeleton under [root]. */
export function disposeObject3D(root) {
  const skeletons = new Set();
  root.traverse((object) => {
    if (object.geometry) object.geometry.dispose();
    if (object.material) {
      const list = Array.isArray(object.material)
        ? object.material
        : [object.material];
      list.forEach(disposeMaterial);
    }
    if (object.isSkinnedMesh && object.skeleton) skeletons.add(object.skeleton);
  });
  skeletons.forEach((skeleton) => skeleton.dispose());
}
