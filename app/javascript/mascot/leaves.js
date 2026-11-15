// Leaves: a PlaneGeometry reshaped once into an outline (ovate cotyledons,
// pointed first true leaves), cupped across and creased along the midrib, then
// bent along its length whenever its inputs change: `curl` 1 is folded against
// the stem and rolled, 0 open; `flutter` is a travelling wave while Aluni
// speaks. Each leaf hangs from a yaw pivot (which way it points from the stem)
// holding a hinge (how far it opens); `lift` raises the blade from its rest
// angle and `wobble` is the idle micro-motion. The upper surface is -Z in the
// blade's own space, so a hinge that opens toward +Z turns it to face up.
import { clamp, lerp, smoothstep } from "mascot/easing"

export const COTYLEDON = {
  length: 0.85, width: 0.56, segments: [6, 12], cup: 0.12, crease: 0.012, roll: 0.3, bend: 0.5, open: 1.38,
  outline: (v) => v < 0.45 ? 0.35 + 0.65 * smoothstep(v / 0.45) : Math.sqrt(Math.max(0, 1 - ((v - 0.45) / 0.55) ** 2))
}
export const TRUE_LEAF = {
  length: 0.9, width: 0.5, segments: [6, 14], cup: 0.08, crease: 0.01, roll: 1.1, bend: 0.6, open: 1.3, young: 0.3,
  outline: (v) => Math.pow(Math.sin(Math.PI * v), 0.85) * Math.pow(1 - 0.5 * v, 0.6)
}

const OPEN_ANGLE = 1.38
const CLOSED_ANGLE = 0.12
const DROOP = 0.18
const FLUTTER_AMOUNT = 0.02
const EPSILON = 1e-4

export function makeLeafMaterial(THREE) {
  return new THREE.MeshStandardMaterial({ vertexColors: true, side: THREE.DoubleSide, roughness: 0.55, metalness: 0 })
}

export function buildLeaf(THREE, material, spec, track, { yaw = 0, phase = 0 } = {}) {
  const [sx, sy] = spec.segments
  const geometry = track(new THREE.PlaneGeometry(spec.width, spec.length, sx, sy))
  const position = geometry.attributes.position
  const count = position.count
  const half = spec.width / 2
  const rest = new Float32Array(count * 3)
  const uv = new Float32Array(count * 2)
  for (let i = 0; i < count; i++) {
    const u = position.getX(i) / half
    const v = (position.getY(i) + spec.length / 2) / spec.length
    const w = spec.outline(v)
    rest[i * 3] = u * half * w
    rest[i * 3 + 1] = v * spec.length
    rest[i * 3 + 2] = -spec.cup * half * u * u + spec.crease * (1 - Math.abs(u)) * w
    uv[i * 2] = u
    uv[i * 2 + 1] = v
  }
  geometry.setAttribute("color", new THREE.BufferAttribute(new Float32Array(count * 3), 3))
  const mesh = new THREE.Mesh(geometry, material)
  mesh.frustumCulled = false

  const hinge = new THREE.Group()
  hinge.add(mesh)
  const pivot = new THREE.Group()
  pivot.rotation.y = yaw
  pivot.add(hinge)

  const current = { curl: NaN, flutter: 0 }
  const deform = ({ curl, flutter = 0, time = 0 }) => {
    const c = clamp(curl, 0, 1)
    const f = Math.max(0, flutter)
    if (f < 1e-3 && current.flutter < 1e-3 && Math.abs(c - current.curl) < EPSILON) return
    current.curl = c
    current.flutter = f
    const roll = spec.roll * c
    const bend = spec.bend * c + DROOP * (1 - c)
    for (let i = 0; i < count; i++) {
      const u = uv[i * 2]
      const v = uv[i * 2 + 1]
      let x = rest[i * 3]
      const y = rest[i * 3 + 1]
      let z = rest[i * 3 + 2]
      z -= roll * half * u * u * 1.5
      x *= 1 - 0.45 * roll * u * u
      z += f * FLUTTER_AMOUNT * v * v * Math.sin(6 * v - 3.4 * time + phase)
      const a = bend * v * v
      const cos = Math.cos(a)
      const sin = Math.sin(a)
      position.setXYZ(i, x, y * cos - z * sin, y * sin + z * cos)
    }
    position.needsUpdate = true
    geometry.computeVertexNormals()
  }

  const setPose = ({ curl, lift = 0, wobble = 0, scale = 1 }) => {
    hinge.rotation.x = lerp(CLOSED_ANGLE, spec.open || OPEN_ANGLE, 1 - clamp(curl, 0, 1)) - lift + wobble
    const s = Math.max(0.001, scale)
    pivot.scale.setScalar(s)
    pivot.visible = scale > 0.01
  }

  const shade = new THREE.Color()
  const leafColor = new THREE.Color()
  const vein = new THREE.Color()
  const mixed = new THREE.Color()
  const recolor = (next) => {
    shade.setHex(next.leafShade)
    leafColor.setHex(next.leaf)
    vein.setHex(next.vein)
    const attribute = geometry.attributes.color
    for (let i = 0; i < count; i++) {
      const u = Math.abs(uv[i * 2])
      const v = uv[i * 2 + 1]
      mixed.copy(shade).lerp(leafColor, 0.25 + 0.75 * v)
      if (spec.young) mixed.lerp(vein, spec.young)
      if (u < 0.2) mixed.lerp(vein, 0.5 * (1 - u / 0.2))
      attribute.setXYZ(i, mixed.r, mixed.g, mixed.b)
    }
    attribute.needsUpdate = true
  }
  recolor({ leafShade: 0x2F6A3E, leaf: 0x4F8F55, vein: 0x86A06E })
  deform({ curl: 1 })
  setPose({ curl: 1, scale: 1 })

  return { pivot, hinge, mesh, deform, setPose, recolor }
}
