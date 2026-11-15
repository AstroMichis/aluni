// Aluni, built procedurally from core Three.js (no assets, no addons, no
// textures): a seedling that has just pushed out of the soil. A slightly
// egg-shaped seed body carries the face low on its front; a short stem rises
// from the crown into two cotyledon leaves; two smaller leaf blades are the
// arms; two root-ball feet carry the gait. The ground shadow is CSS.
//
// Budget: about 4.4k triangles and 11 draw calls (seed, two eyes, face, stem,
// two leaves, two arms, two feet). Every geometry and material is tracked so
// dispose() frees the GPU in one call.
//
//   const { group, anchor, parts, applyPalette, dispose } = buildCharacter(THREE, palette)
//
// `anchor` is a non-bobbing Object3D above the head: the controller projects
// it to place the speech bubble. `parts` is what the animator drives.

export const BODY_Y = 1.4
const BODY_SCALE_Y = 1.12
const ROUGHNESS = 0.75

const LEAF_REST = { x: -0.3, z: 0.95 }
const ARM_REST = { x: -0.25, z: 2.35 }

export function buildCharacter(THREE, palette) {
  const geometries = []
  const track = (geometry) => { geometries.push(geometry); return geometry }
  const standard = (color) => new THREE.MeshStandardMaterial({ color, roughness: ROUGHNESS, metalness: 0 })

  const materials = {
    seed: standard(palette.seed),
    seedShade: standard(palette.seedShade),
    leaf: standard(palette.leaf),
    leafShade: standard(palette.leafShade),
    eye: new THREE.MeshStandardMaterial({
      color: palette.eye, emissive: palette.eyeGlow, emissiveIntensity: 0.9, roughness: 0.35, metalness: 0
    }),
    face: new THREE.MeshBasicMaterial({ vertexColors: true })
  }

  const group = new THREE.Group()

  // The body group bobs, rolls, nods and breathes; the feet and the anchor
  // hang off the root so they stay put.
  const body = new THREE.Group()
  body.position.y = BODY_Y
  group.add(body)

  const seed = new THREE.Mesh(track(new THREE.SphereGeometry(1, 32, 22)), materials.seed)
  seed.scale.set(1, BODY_SCALE_Y, 1)
  body.add(seed)

  // z of the egg's surface at (x, y) in body space; the face hugs it.
  const surfaceZ = (x, y) => Math.sqrt(Math.max(0, 1 - x * x - (y / BODY_SCALE_Y) ** 2))

  const eyes = new THREE.Group()
  const eyeGeometry = track(new THREE.SphereGeometry(0.13, 14, 10))
  const eyeMeshes = [-0.3, 0.3].map((x) => {
    const eye = new THREE.Mesh(eyeGeometry, materials.eye)
    eye.position.set(x, -0.08, surfaceZ(x, -0.08) - 0.05)
    return eye
  })
  eyes.add(...eyeMeshes)
  body.add(eyes)

  const face = buildFace(THREE, materials.face, surfaceZ, palette, track)
  body.add(face.mesh)

  const stem = new THREE.Mesh(track(new THREE.CapsuleGeometry(0.085, 0.55, 4, 12)), materials.leafShade)
  stem.position.set(0, 1.3, 0.02)
  body.add(stem)

  const extrude = { depth: 0.05, bevelEnabled: true, bevelThickness: 0.02, bevelSize: 0.02, bevelSegments: 2, curveSegments: 8 }
  const leafGeometry = track(new THREE.ExtrudeGeometry(leafShape(THREE, 1.0, 0.78), extrude))
  leafGeometry.translate(0, 0, -0.025)
  const leaves = [-1, 1].map((side) => {
    const pivot = new THREE.Group()
    pivot.position.set(0.06 * side, 1.62, 0.02)
    pivot.userData.rest = { x: LEAF_REST.x, z: -LEAF_REST.z * side }
    pivot.userData.phase = side < 0 ? 0 : 1.9
    pivot.rotation.set(pivot.userData.rest.x, 0, pivot.userData.rest.z)
    pivot.add(new THREE.Mesh(leafGeometry, materials.leaf))
    body.add(pivot)
    return pivot
  })

  const armGeometry = track(new THREE.ExtrudeGeometry(leafShape(THREE, 0.75, 0.3), extrude))
  armGeometry.translate(0, 0, -0.025)
  const arms = [-1, 1].map((side) => {
    const pivot = new THREE.Group()
    pivot.position.set(0.88 * side, 0.3, 0.1)
    pivot.userData.rest = { x: ARM_REST.x, z: -ARM_REST.z * side }
    pivot.userData.phase = side < 0 ? 0.7 : 2.6
    pivot.rotation.set(pivot.userData.rest.x, 0, pivot.userData.rest.z)
    pivot.add(new THREE.Mesh(armGeometry, materials.leafShade))
    body.add(pivot)
    return pivot
  })

  const footGeometry = track(new THREE.LatheGeometry(footProfile(THREE), 16))
  const feet = [-1, 1].map((side) => {
    const pivot = new THREE.Group()
    pivot.position.set(0.4 * side, 0.5, 0.02)
    const foot = new THREE.Mesh(footGeometry, materials.seedShade)
    foot.position.y = -0.5
    pivot.add(foot)
    group.add(pivot)
    return pivot
  })

  const anchor = new THREE.Object3D()
  anchor.position.set(0.45, 3.45, 0.4)
  group.add(anchor)

  const parts = {
    body, bodyY: BODY_Y, eyes, eyeMeshes, mouth: face.mouth,
    leaves, armLeft: arms[0], armRight: arms[1], feet
  }

  const applyPalette = (next) => {
    materials.seed.color.setHex(next.seed)
    materials.seedShade.color.setHex(next.seedShade)
    materials.leaf.color.setHex(next.leaf)
    materials.leafShade.color.setHex(next.leafShade)
    materials.eye.color.setHex(next.eye)
    materials.eye.emissive.setHex(next.eyeGlow)
    face.recolor(next)
  }

  const dispose = () => {
    geometries.forEach((geometry) => geometry.dispose())
    Object.values(materials).forEach((material) => material.dispose())
  }

  return { group, anchor, parts, applyPalette, dispose }
}

// A broad, rounded leaf drawn with quadratic curves; base at the origin,
// length along +Y, so a pivot at its base turns it like a real leaf.
function leafShape(THREE, length, width) {
  const half = width / 2
  const shape = new THREE.Shape()
  shape.moveTo(0, 0)
  shape.quadraticCurveTo(half * 1.25, length * 0.12, half, length * 0.62)
  shape.quadraticCurveTo(half * 0.55, length * 1.02, 0, length)
  shape.quadraticCurveTo(-half * 0.55, length * 1.02, -half, length * 0.62)
  shape.quadraticCurveTo(-half * 1.25, length * 0.12, 0, 0)
  return shape
}

// A squashed bulb with ridges, revolved into a root-ball foot (height 0.46).
function footProfile(THREE) {
  const profile = [
    [0, 0], [0.2, 0.01], [0.3, 0.05], [0.36, 0.12], [0.38, 0.2],
    [0.36, 0.29], [0.3, 0.37], [0.2, 0.43], [0.08, 0.46], [0, 0.46]
  ]
  return profile.map(([r, y], i) => {
    const ridge = i > 1 && i < profile.length - 2 ? (i % 2 ? 0.015 : -0.015) : 0
    return new THREE.Vector2(Math.max(0, r + ridge), y)
  })
}

// Cheeks and mouth are one ShapeGeometry (three Shapes) with a vertex colour
// attribute and one MeshBasicMaterial: one draw call for the whole face. Every
// vertex is pushed onto the egg's surface. The mouth opens by scaling its own
// vertices (the animator calls mouth.open(amount)), so it needs no mesh of its own.
function buildFace(THREE, material, surfaceZ, palette, track) {
  const MOUTH_TOP = -0.42
  const cheekLeft = new THREE.Shape()
  cheekLeft.absellipse(-0.56, -0.32, 0.13, 0.085, 0, Math.PI * 2, false, 0)
  const cheekRight = new THREE.Shape()
  cheekRight.absellipse(0.56, -0.32, 0.13, 0.085, 0, Math.PI * 2, false, 0)
  const smile = new THREE.Shape()
  smile.moveTo(-0.22, MOUTH_TOP)
  smile.quadraticCurveTo(0, -0.58, 0.22, MOUTH_TOP)
  smile.quadraticCurveTo(0, -0.66, -0.22, MOUTH_TOP)

  const geometry = track(new THREE.ShapeGeometry([cheekLeft, cheekRight, smile], 10))
  const position = geometry.attributes.position
  const count = position.count
  const colors = new Float32Array(count * 3)
  const mouthIndices = []
  for (let i = 0; i < count; i++) {
    const x = position.getX(i), y = position.getY(i)
    if (Math.abs(x) < 0.3) mouthIndices.push(i)
    position.setZ(i, surfaceZ(x, y) + 0.012)
  }
  geometry.setAttribute("color", new THREE.BufferAttribute(colors, 3))
  const base = Float32Array.from(position.array)
  const mesh = new THREE.Mesh(geometry, material)

  const color = new THREE.Color()
  const recolor = (next) => {
    const attribute = geometry.attributes.color
    const mouthSet = new Set(mouthIndices)
    for (let i = 0; i < count; i++) {
      color.setHex(mouthSet.has(i) ? next.mouth : next.cheek)
      attribute.setXYZ(i, color.r, color.g, color.b)
    }
    attribute.needsUpdate = true
  }
  recolor(palette)

  let current = 0
  const mouth = {
    // amount 0 is the resting smile; 1 opens it to about 2.6x its height.
    open(amount) {
      const next = Math.max(0, Math.min(1, amount))
      if (Math.abs(next - current) < 0.002) return
      current = next
      const stretch = 1 + next * 1.6
      mouthIndices.forEach((i) => {
        const x = base[i * 3], y = base[i * 3 + 1]
        const stretched = MOUTH_TOP + (y - MOUTH_TOP) * stretch
        position.setY(i, stretched)
        position.setZ(i, surfaceZ(x, stretched) + 0.012)
      })
      position.needsUpdate = true
    }
  }

  return { mesh, mouth, recolor }
}
