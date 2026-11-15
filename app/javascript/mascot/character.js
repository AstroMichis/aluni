// Aluni, built procedurally from core Three.js (no assets, no addons): a dicot
// seedling shown herbarium-style. A thin soil disc at SOIL_Y with the roots
// hanging below it; on the disc, two seed-coat halves, the hypocotyl (a bent
// tube), two cotyledons at its node, the first true leaves and a small bud with
// a gold glow at its tip. No face: expression comes from posture and light
// (animator.js). About 3.5k triangles, 14 draw calls.
//
//   const { group, anchor, soilAnchor, parts, applyPalette, dispose } = buildCharacter(THREE, palette)
//
// `anchor` is an Object3D above the plant that the controller projects to place
// the speech bubble; `soilAnchor` is the soil point it projects for the root
// travel. `parts` is what the animator drives:
//   soil { mesh, recolor }, roots { group, reveal }, lean (Object3D at the soil
//   point: sway and lean), plant (Group inside it, yawed PLANT_YAW), seed
//   { group, setOpen(open, sink) }, stem { mesh, node, tip, deform }, cotyledons
//   and trueLeaves ([{ pivot, setPose, deform }]), bud, halo, glow { set(level) }.
import { buildSoil } from "mascot/soil"
import { buildSeedCoat } from "mascot/seed"
import { buildHypocotyl } from "mascot/stem"
import { buildLeaf, makeLeafMaterial, COTYLEDON, TRUE_LEAF } from "mascot/leaves"
import { buildRoots } from "mascot/roots"

export const SOIL_Y = 0.9
export const PLANT_YAW = 0.55
export const ANCHOR = [0.3, 2.75, 0.3]
const TRUE_LEAF_YAW = -0.5
const HALO_SIZE = 64

export function buildCharacter(THREE, palette) {
  const geometries = []
  const textures = []
  const track = (geometry) => { geometries.push(geometry); return geometry }

  const group = new THREE.Group()

  const soil = buildSoil(THREE, palette, track)
  soil.mesh.position.y = SOIL_Y
  group.add(soil.mesh)

  const roots = buildRoots(THREE, palette, track)
  roots.group.position.y = SOIL_Y
  group.add(roots.group)

  // The lean pivots at the soil point; the plant inside it is turned a little
  // so both leaf pairs read in three-quarter view.
  const lean = new THREE.Object3D()
  lean.position.y = SOIL_Y
  group.add(lean)
  const plant = new THREE.Group()
  plant.rotation.y = PLANT_YAW
  lean.add(plant)

  const seed = buildSeedCoat(THREE, palette, track)
  plant.add(seed.group)

  const stem = buildHypocotyl(THREE, palette, track)
  plant.add(stem.mesh, stem.node, stem.tip)

  const leafMaterial = makeLeafMaterial(THREE)
  const cotyledons = [-1, 1].map((side, i) => {
    const leaf = buildLeaf(THREE, leafMaterial, COTYLEDON, track, { yaw: side * Math.PI / 2, phase: i * 1.9 })
    leaf.pivot.position.x = 0.03 * side
    stem.node.add(leaf.pivot)
    return leaf
  })
  // Decussate: the first true leaves stand at right angles to the cotyledons.
  const trueLeaves = [0, Math.PI].map((yaw, i) => {
    const leaf = buildLeaf(THREE, leafMaterial, TRUE_LEAF, track, { yaw: yaw + TRUE_LEAF_YAW, phase: 0.7 + i * 2.6 })
    leaf.pivot.position.y = 0.02
    stem.tip.add(leaf.pivot)
    return leaf
  })

  const budColor = new THREE.Color()
  const budMaterial = new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: palette.tip, emissiveIntensity: 0.4, roughness: 0.5, metalness: 0 })
  const bud = new THREE.Mesh(track(new THREE.SphereGeometry(0.075, 12, 8)), budMaterial)
  bud.scale.set(1, 1.3, 1)
  bud.position.y = 0.04
  stem.tip.add(bud)

  // A soft sprite of light around the bud: the "attention light".
  const haloTexture = radialTexture(THREE)
  let halo = null
  let haloMaterial = null
  if (haloTexture) {
    textures.push(haloTexture)
    haloMaterial = new THREE.SpriteMaterial({ map: haloTexture, color: palette.tip, transparent: true, opacity: 0.5, depthWrite: false })
    halo = new THREE.Sprite(haloMaterial)
    halo.scale.setScalar(0.4)
    halo.position.y = 0.06
    stem.tip.add(halo)
  }

  const anchor = new THREE.Object3D()
  anchor.position.set(...ANCHOR)
  group.add(anchor)
  const soilAnchor = new THREE.Object3D()
  soilAnchor.position.set(0, SOIL_Y, 0)
  group.add(soilAnchor)

  // level 0 is dark, 1 the full speaking glow.
  const glow = {
    set(level) {
      budMaterial.emissiveIntensity = 0.15 + 1.6 * level
      if (haloMaterial) {
        haloMaterial.opacity = 0.9 * level
        halo.scale.setScalar(0.45 + 0.8 * level)
      }
    }
  }

  const parts = { soil, roots, lean, plant, seed, stem, cotyledons, trueLeaves, bud, halo, glow }

  const applyPalette = (next) => {
    soil.recolor(next)
    seed.recolor(next)
    stem.recolor(next)
    cotyledons.forEach((leaf) => leaf.recolor(next))
    trueLeaves.forEach((leaf) => leaf.recolor(next))
    roots.material.color.setHex(next.root)
    budColor.setHex(next.tip).lerp(new THREE.Color(next.leaf), 0.45)
    budMaterial.color.copy(budColor)
    budMaterial.emissive.setHex(next.tip)
    if (haloMaterial) haloMaterial.color.setHex(next.tip)
  }
  applyPalette(palette)

  const dispose = () => {
    geometries.forEach((geometry) => geometry.dispose())
    const materials = [soil.material, seed.material, stem.material, leafMaterial, roots.material, budMaterial, haloMaterial]
    materials.forEach((material) => { if (material) material.dispose() })
    textures.forEach((texture) => texture.dispose())
  }

  return { group, anchor, soilAnchor, parts, applyPalette, dispose }
}

// A radial white-to-transparent gradient for the halo sprite; null when the
// 2D canvas is unavailable (the halo is then skipped).
function radialTexture(THREE) {
  const canvas = document.createElement("canvas")
  canvas.width = canvas.height = HALO_SIZE
  const context = canvas.getContext("2d")
  if (!context) return null
  const half = HALO_SIZE / 2
  const gradient = context.createRadialGradient(half, half, 0, half, half, half)
  gradient.addColorStop(0, "rgba(255, 255, 255, 1)")
  gradient.addColorStop(0.35, "rgba(255, 255, 255, 0.45)")
  gradient.addColorStop(1, "rgba(255, 255, 255, 0)")
  context.fillStyle = gradient
  context.fillRect(0, 0, HALO_SIZE, HALO_SIZE)
  const texture = new THREE.CanvasTexture(canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  return texture
}
