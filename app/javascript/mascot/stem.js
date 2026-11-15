// The hypocotyl: one open cylinder whose rings are laid along a cubic Bezier
// spine whenever its inputs change. `hook` 1 is the arch a real seedling pushes
// out of the soil with (tip down), 0 the straight stem; `length` is the stem's
// length in world units; `lean` {x, z} bends the upper stem toward a target.
// Two frames ride on the spine for the leaves: `node` (the cotyledons, at
// NODE_LENGTH or the tip when the stem is shorter) and `tip` (the bud and the
// first true leaves, at the end). Vertex colours run leaf-shade to stem.
import { clamp } from "mascot/easing"

const RADIUS_TOP = 0.05
const RADIUS_BOTTOM = 0.075
const RADIAL = 10
const RINGS = 24
const EPSILON = 1e-4
export const NODE_LENGTH = 1.25

export function buildHypocotyl(THREE, palette, track) {
  const geometry = track(new THREE.CylinderGeometry(RADIUS_TOP, RADIUS_BOTTOM, 1, RADIAL, RINGS, true))
  const position = geometry.attributes.position
  const count = position.count
  const base = Float32Array.from(position.array)
  geometry.setAttribute("color", new THREE.BufferAttribute(new Float32Array(count * 3), 3))
  const material = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.6, metalness: 0 })
  const mesh = new THREE.Mesh(geometry, material)
  mesh.frustumCulled = false
  const node = new THREE.Object3D()
  const tip = new THREE.Object3D()

  const p0 = new THREE.Vector3()
  const p1 = new THREE.Vector3()
  const p2 = new THREE.Vector3()
  const p3 = new THREE.Vector3()
  const endDir = new THREE.Vector3()
  const point = new THREE.Vector3()
  const tangent = new THREE.Vector3()
  const normal = new THREE.Vector3()
  const binormal = new THREE.Vector3()
  const reference = new THREE.Vector3(0, 0, 1)
  const frame = new THREE.Matrix4()
  const normals = () => geometry.attributes.normal

  const bezier = (t, out) => {
    const k = 1 - t
    out.set(0, 0, 0)
    out.addScaledVector(p0, k * k * k)
    out.addScaledVector(p1, 3 * k * k * t)
    out.addScaledVector(p2, 3 * k * t * t)
    out.addScaledVector(p3, t * t * t)
    return out
  }
  const derivative = (t, out) => {
    const k = 1 - t
    out.set(0, 0, 0)
    out.addScaledVector(p1, 3 * k * k).addScaledVector(p0, -3 * k * k)
    out.addScaledVector(p2, 6 * k * t).addScaledVector(p1, -6 * k * t)
    out.addScaledVector(p3, 3 * t * t).addScaledVector(p2, -3 * t * t)
    return out
  }
  // Point and an orthonormal frame (normal, tangent, binormal) at spine parameter t.
  const frameAt = (t) => {
    bezier(t, point)
    derivative(t, tangent)
    if (tangent.lengthSq() < 1e-10) tangent.set(0, 1, 0)
    tangent.normalize()
    normal.crossVectors(reference, tangent)
    if (normal.lengthSq() < 1e-8) normal.set(1, 0, 0)
    normal.normalize()
    binormal.crossVectors(normal, tangent)
  }
  const placeFrame = (object, t) => {
    frameAt(t)
    object.position.copy(point)
    frame.makeBasis(normal, tangent, binormal)
    object.quaternion.setFromRotationMatrix(frame)
  }

  const last = { length: NaN, hook: NaN, leanX: NaN, leanZ: NaN }

  const deform = ({ length, hook = 0, lean = null }) => {
    const L = Math.max(0.001, length)
    const h = clamp(hook, 0, 1)
    const lx = lean ? lean.x || 0 : 0
    const lz = lean ? lean.z || 0 : 0
    if (Math.abs(L - last.length) < EPSILON && Math.abs(h - last.hook) < EPSILON &&
        Math.abs(lx - last.leanX) < EPSILON && Math.abs(lz - last.leanZ) < EPSILON) return
    last.length = L; last.hook = h; last.leanX = lx; last.leanZ = lz

    p0.set(0, 0, 0)
    p1.set(0, 0.4 * L, 0)
    p3.set(0.5 * L * h + 0.5 * L * lx, L * (1 - 0.35 * h), 0.05 * L * h + 0.5 * L * lz)
    endDir.set(0.6 * h + 0.6 * lx, 1 - 1.8 * h, 0.6 * lz).normalize()
    p2.copy(p3).addScaledVector(endDir, -0.35 * L)

    let ringV = NaN
    for (let i = 0; i < count; i++) {
      const bx = base[i * 3]
      const v = base[i * 3 + 1] + 0.5
      const bz = base[i * 3 + 2]
      if (v !== ringV) { frameAt(v); ringV = v }
      position.setXYZ(
        i,
        point.x + normal.x * bx + binormal.x * bz,
        point.y + normal.y * bx + binormal.y * bz,
        point.z + normal.z * bx + binormal.z * bz
      )
    }
    position.needsUpdate = true
    geometry.computeVertexNormals()
    // The seam's duplicated vertices only see the faces on their own side:
    // average them so the shading wraps cleanly.
    const n = normals()
    for (let ring = 0; ring <= RINGS; ring++) {
      const a = ring * (RADIAL + 1)
      const b = a + RADIAL
      const x = (n.getX(a) + n.getX(b)) / 2
      const y = (n.getY(a) + n.getY(b)) / 2
      const z = (n.getZ(a) + n.getZ(b)) / 2
      n.setXYZ(a, x, y, z)
      n.setXYZ(b, x, y, z)
    }
    n.needsUpdate = true

    placeFrame(node, Math.min(1, NODE_LENGTH / L))
    placeFrame(tip, 1)
  }

  const shade = new THREE.Color()
  const stemColor = new THREE.Color()
  const mixed = new THREE.Color()
  const recolor = (next) => {
    shade.setHex(next.leafShade)
    stemColor.setHex(next.stem)
    const attribute = geometry.attributes.color
    for (let i = 0; i < count; i++) {
      mixed.copy(shade).lerp(stemColor, clamp(base[i * 3 + 1] + 0.5, 0, 1))
      attribute.setXYZ(i, mixed.r, mixed.g, mixed.b)
    }
    attribute.needsUpdate = true
  }
  recolor(palette)
  deform({ length: 0.001, hook: 1 })

  return { mesh, node, tip, material, deform, recolor }
}
