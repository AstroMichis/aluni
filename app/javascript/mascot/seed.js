// The seed coat: two half-shells of a seed standing on end in the soil. They
// crack apart on hinges at the soil line as the hypocotyl pushes up, lie open
// beside the stem, and sink into the soil once the roots show (stage 3).
import { clamp } from "mascot/easing"

const RADIUS = 0.36
const SCALE = [0.8, 1, 0.78]
const OPEN_ANGLE = 1.25
const OPEN_SHIFT = 0.05
const SETTLE_SINK = 0.04

export function buildSeedCoat(THREE, palette, track) {
  // The x <= 0 half; the right half is the same geometry turned around.
  const geometry = track(new THREE.SphereGeometry(RADIUS, 18, 12, -Math.PI / 2, Math.PI))
  const position = geometry.attributes.position
  geometry.setAttribute("color", new THREE.BufferAttribute(new Float32Array(position.count * 3), 3))
  const material = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.7, metalness: 0, side: THREE.DoubleSide })

  const group = new THREE.Group()
  const halves = [-1, 1].map((side) => {
    const pivot = new THREE.Group()
    const shell = new THREE.Mesh(geometry, material)
    shell.scale.set(SCALE[0], SCALE[1], SCALE[2])
    shell.rotation.y = side > 0 ? Math.PI : 0
    shell.position.y = RADIUS * SCALE[1]
    pivot.add(shell)
    pivot.userData.side = side
    group.add(pivot)
    return pivot
  })

  const coat = new THREE.Color()
  const shade = new THREE.Color()
  const mixed = new THREE.Color()
  const recolor = (next) => {
    coat.setHex(next.seedCoat)
    shade.setHex(next.seedCoatShade)
    const attribute = geometry.attributes.color
    for (let i = 0; i < position.count; i++) {
      const k = clamp((position.getY(i) / RADIUS + 1) / 2, 0, 1)
      mixed.copy(shade).lerp(coat, 0.35 + 0.65 * k)
      attribute.setXYZ(i, mixed.r, mixed.g, mixed.b)
    }
    attribute.needsUpdate = true
  }
  recolor(palette)

  // open 0 is the closed seed, 1 both halves lying open; sink 0..1 takes them
  // into the soil (they shrink as they go, so nothing pokes out below the disc).
  const setOpen = (open, sink) => {
    const o = clamp(open, 0, 1)
    const s = clamp(sink, 0, 1)
    halves.forEach((pivot) => {
      const side = pivot.userData.side
      pivot.rotation.z = -side * OPEN_ANGLE * o
      pivot.position.x = side * (0.015 + OPEN_SHIFT * o)
      pivot.position.y = -SETTLE_SINK * o - 0.12 * s
      pivot.scale.setScalar(Math.max(0.001, 1 - s))
    })
    group.visible = s < 0.999
  }
  setOpen(0, 0)

  return { group, halves, material, recolor, setOpen }
}
