// The soil: a thin dark disc Aluni stands in, shown herbarium-style with the
// roots hanging below it. One LatheGeometry with vertex colours (the top face
// in soil, the rim and underside in soil-shade). The mesh's origin is the
// centre of the top face, so scaling it (retract, emerge) happens about the
// soil line.
import { clamp } from "mascot/easing"

export const SOIL_RADIUS = 0.9

// (radius, y) from the underside's centre up and out to the top's centre, so
// LatheGeometry's normals face outward.
const PROFILE = [
  [0, -0.14], [0.47, -0.135], [0.83, -0.11], [0.92, -0.045], [0.89, 0], [0.72, 0.022], [0.38, 0.036], [0, 0.04]
]

export function buildSoil(THREE, palette, track) {
  const points = PROFILE.map(([r, y]) => new THREE.Vector2(r, y))
  const geometry = track(new THREE.LatheGeometry(points, 36))
  const position = geometry.attributes.position
  geometry.setAttribute("color", new THREE.BufferAttribute(new Float32Array(position.count * 3), 3))
  const material = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95, metalness: 0 })
  const mesh = new THREE.Mesh(geometry, material)

  const top = new THREE.Color()
  const shade = new THREE.Color()
  const mixed = new THREE.Color()
  const recolor = (next) => {
    top.setHex(next.soil)
    shade.setHex(next.soilShade)
    const attribute = geometry.attributes.color
    for (let i = 0; i < position.count; i++) {
      const k = clamp((position.getY(i) + 0.045) / 0.085, 0, 1)
      mixed.copy(shade).lerp(top, k)
      attribute.setXYZ(i, mixed.r, mixed.g, mixed.b)
    }
    attribute.needsUpdate = true
  }
  recolor(palette)

  return { mesh, material, recolor }
}
