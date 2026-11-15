// The roots under the soil disc: a taproot and three laterals as thin tubes,
// revealed from the soil down by growing each tube's draw range (TubeGeometry's
// index runs along the tube), the laterals once the taproot has passed them.
import { clamp } from "mascot/easing"

const TUBULAR = 20
const RADIAL = 6
const INDICES_PER_SEGMENT = RADIAL * 6
const TAPROOT = [[0, 0, 0], [0.03, -0.25, -0.05], [-0.03, -0.5, 0.03], [0.05, -0.82, -0.06]]
const LATERALS = [
  { at: 0.2, dir: [0.42, -0.3, 0.12] },
  { at: 0.45, dir: [-0.5, -0.26, -0.1] },
  { at: 0.7, dir: [0.3, -0.28, 0.26] }
]

export function buildRoots(THREE, palette, track) {
  const material = new THREE.MeshStandardMaterial({ color: palette.root, roughness: 0.8, metalness: 0 })
  const group = new THREE.Group()
  const vector = (xyz) => new THREE.Vector3(...xyz)
  const tube = (curve, radius) => {
    const geometry = track(new THREE.TubeGeometry(curve, TUBULAR, radius, RADIAL, false))
    const mesh = new THREE.Mesh(geometry, material)
    group.add(mesh)
    return geometry
  }

  const taprootCurve = new THREE.CatmullRomCurve3(TAPROOT.map(vector))
  const taproot = tube(taprootCurve, 0.03)
  const laterals = LATERALS.map(({ at, dir }) => {
    const start = taprootCurve.getPoint(at)
    const end = start.clone().add(vector(dir))
    const mid = start.clone().lerp(end, 0.5).add(new THREE.Vector3(dir[2] * 0.3, 0.06, -dir[0] * 0.25))
    return { at, geometry: tube(new THREE.CatmullRomCurve3([start, mid, end]), 0.017) }
  })

  const setRange = (geometry, k) => {
    geometry.setDrawRange(0, Math.round(clamp(k, 0, 1) * TUBULAR) * INDICES_PER_SEGMENT)
  }
  // amount 0 hides every root, 1 shows them all: the taproot over the first
  // 70%, each lateral from the moment the taproot reaches it.
  const reveal = (amount) => {
    const a = clamp(amount, 0, 1)
    setRange(taproot, a / 0.7)
    laterals.forEach(({ at, geometry }) => setRange(geometry, (a - 0.7 * at) / (1 - 0.7 * at)))
    group.visible = a > 0.001
  }
  reveal(0)

  return { group, material, reveal }
}
