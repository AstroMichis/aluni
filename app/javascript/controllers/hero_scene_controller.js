import { Controller } from "@hotwired/stimulus"
import { reducedMotion } from "preferences/motion"

// The landing's background scene: rolling crop fields drawn with Three.js
// (vendored, loaded lazily so only this page pays for it). It is the one
// signature of the site. The tour (scroll_story_controller) tells it where the
// reader is through window "landing:progress" events; the camera flies between
// keyframes, a pin drops on the home field, the fields recolour by crop and by
// rotation strategy, and the light turns warm and low for the alerts step.
//
// Lifecycle rules (keep when changing the geometry):
// - prefers-reduced-motion: reveal the copy, show the CSS backdrop, never import Three.
// - any failure (no WebGL, import error, a frame throwing): warn, tear down, show the backdrop.
// - the copy is revealed by 1.5 s no matter what, so a slow import never hides it.
// - resize/orientation debounced through rAF; clock paused when hidden.
// - theme palette follows html[data-theme] live through a MutationObserver.
// - disconnect() removes every listener and disposes every GPU resource,
//   which also covers Turbo navigation.

const MAX_RENDER_W = 2560
const MAX_RENDER_H = 1440
const INTRO_DURATION = 2.4
const REVEAL_AT = 0.9
const SAFETY_REVEAL_MS = 1500

const WORLD = 60            // the ground is WORLD x WORLD units
const FIELDS = 5            // FIELDS x FIELDS patches
const FIELD = WORLD / FIELDS
const HEDGE = 0.35          // hedgerow width along a patch edge
const HEMI_INTENSITY = 1.6
const SUN_INTENSITY = 2.4

// Crop per patch, row by row; patch 12 (the centre) is the farmer's field.
const LAYOUT = [
  "corn", "soy", "corn", "cover", "soy",
  "soy", "corn", "soy", "corn", "oats",
  "corn", "soy", "corn", "soy", "corn",
  "cover", "corn", "soy", "corn", "soy",
  "soy", "oats", "corn", "soy", "corn"
]
const CENTER = 12
const NEIGHBOURS = [6, 7, 8, 11, 13, 16, 17, 18]
const OUTER = [0, 1, 2, 3, 4, 5, 9, 10, 14, 15, 19, 20, 21, 22, 23, 24]

// Three rotation strategies for the 3x3 centre block (tour step 4).
const ROTATIONS = {
  current:     { 6: "corn", 7: "soy", 8: "corn", 11: "soy", 12: "corn", 13: "soy", 16: "corn", 17: "soy", 18: "corn" },
  small_grain: { 6: "oats", 7: "corn", 8: "soy", 11: "soy", 12: "oats", 13: "corn", 16: "corn", 17: "soy", 18: "oats" },
  cover:       { 6: "cover", 7: "corn", 8: "cover", 11: "soy", 12: "cover", 13: "soy", 16: "cover", 17: "corn", 18: "cover" }
}
const ROTATION_ORDER = ["current", "small_grain", "cover"]
const CROP_SCALE = { corn: 1.0, soy: 0.55, oats: 0.7, cover: 0.35, bare: 0.001 }

// Hex ints taken from the design tokens (base/variables.css).
const PALETTES = {
  dark: {
    fog: 0x0F2920, sky: 0x2C624A, ground: 0x173D2D, sun: 0xF1EBDD, sunAlert: 0xE3A845,
    hedge: 0x10291F, soil: 0x3A3328, corn: 0xB69A5B, soy: 0x6B7650, oats: 0xC9AF72, cover: 0x3E7A4A, bare: 0x4A3F33,
    highlight: 0xD9C48F, frost: 0xC8C3B2, pin: 0xB69A5B, ring: 0xF1EBDD, warning: 0xE3A845
  },
  light: {
    fog: 0xF1EBDD, sky: 0xFAF7EF, ground: 0xB9AD90, sun: 0xFFFFFF, sunAlert: 0xE3A845,
    hedge: 0x3F5A4C, soil: 0x8C7332, corn: 0xC9AF72, soy: 0x6B7650, oats: 0xB69A5B, cover: 0x35703F, bare: 0xB9AD90,
    highlight: 0x173D2D, frost: 0xFFFFFF, pin: 0x173D2D, ring: 0x26364A, warning: 0x8A6A1E
  }
}

// Camera keyframes by tour step (0 hero ... 6 past the last step).
const CAMERA = [
  { pos: [0, 15, 30], look: [0, 0, -4] },
  { pos: [4, 9, 14], look: [0, 0.5, 0] },
  { pos: [3, 5, 8], look: [0, 0.3, 0] },
  { pos: [-6, 10, 14], look: [0, 0, 0] },
  { pos: [0, 18, 18], look: [0, 0, -2] },
  { pos: [6, 7, 10], look: [0, 0.5, 0] },
  { pos: [0, 24, 34], look: [0, 0, -6] }
]
const INTRO_FROM = [0, 22, 42]

const clamp01 = (t) => Math.min(1, Math.max(0, t))
const easeOutCubic = (t) => 1 - Math.pow(1 - clamp01(t), 3)
const smoothstep = (t) => { const k = clamp01(t); return k * k * (3 - 2 * k) }
const lerp = (a, b, t) => a + (b - a) * t

// Deterministic value noise, so the fields look the same on every visit.
const hash = (x, z) => { const s = Math.sin(x * 127.1 + z * 311.7) * 43758.5453; return s - Math.floor(s) }
const noise = (x, z) => {
  const xi = Math.floor(x), zi = Math.floor(z)
  const u = smoothstep(x - xi), v = smoothstep(z - zi)
  const a = hash(xi, zi), b = hash(xi + 1, zi), c = hash(xi, zi + 1), d = hash(xi + 1, zi + 1)
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
}
const height = (x, z) => noise(x * 0.08 + 7, z * 0.08 + 3) * 1.2 + noise(x * 0.25, z * 0.25) * 0.3 - 0.75
const patchAt = (x, z) => {
  const col = Math.min(FIELDS - 1, Math.max(0, Math.floor((x + WORLD / 2) / FIELD)))
  const row = Math.min(FIELDS - 1, Math.max(0, Math.floor((z + WORLD / 2) / FIELD)))
  return row * FIELDS + col
}
const nearEdge = (x, z) => {
  const fx = (x + WORLD / 2) % FIELD, fz = (z + WORLD / 2) % FIELD
  return fx < HEDGE || fx > FIELD - HEDGE || fz < HEDGE || fz > FIELD - HEDGE
}

export default class extends Controller {
  static targets = ["canvas", "heroContent"]
  // The view passes its own BEM classes (data-hero-scene-hidden-class,
  // -visible-class, -fallback-class) so the controller stays layout-agnostic.
  static classes = ["hidden", "visible", "fallback"]
  static values = { progressEvent: { type: String, default: "landing:progress" } }

  connect() {
    this._connected = true
    this.story = { step: 0, progress: 0, heroProgress: 0, scroll: 0 }
    this.revealTimer = setTimeout(() => this.revealHeroContent(), SAFETY_REVEAL_MS)

    if (reducedMotion()) {
      this.showFallback()
      return
    }
    this.paused = false
    this.mouse = { x: 0, y: 0 }
    this.smoothMouse = { x: 0, y: 0 }
    this._evaluateDevice()
    this._currentTheme = this._readTheme()
    this.palette = PALETTES[this._currentTheme]
    this.initScene()
  }

  _readTheme() {
    return document.documentElement.dataset.theme === "light" ? "light" : "dark"
  }

  // Touch devices get the lighter path regardless of viewport width.
  _evaluateDevice() {
    const isTouchPrimary = window.matchMedia("(pointer: coarse)").matches
    const isNarrow = window.innerWidth < 768
    this.isMobile = isTouchPrimary || isNarrow
  }

  async initScene() {
    try {
      const THREE = await import("three")
      if (!this._connected) return
      this.THREE = THREE
      this._tmpColor = new THREE.Color()
      this._tmpColor2 = new THREE.Color()
      this._tmpVec = new THREE.Vector3()
      this._tmpMatrix = new THREE.Matrix4()

      this.scene = new THREE.Scene()
      this.scene.fog = new THREE.Fog(this.palette.fog, 28, 70)
      this.camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.1, 120)
      this.camera.position.set(...INTRO_FROM)
      this.look = new THREE.Vector3(...CAMERA[0].look)
      this.camera.lookAt(this.look)

      this.renderer = new THREE.WebGLRenderer({ alpha: true, antialias: !this.isMobile, powerPreference: "low-power" })
      this._applyRendererSize()
      this.renderer.setPixelRatio(this._chooseRendererPixelRatio())
      if (!this.hasCanvasTarget) { this.showFallback(); return }
      this.canvasTarget.appendChild(this.renderer.domElement)

      this.group = new THREE.Group()
      this.scene.add(this.group)

      this.patchCrop = LAYOUT.slice()
      this.patchTint = new Array(FIELDS * FIELDS).fill(null)
      this.barePatches = new Set()
      this.buildLights(THREE)
      this.buildGround(THREE)
      this.buildCrops(THREE)
      this.buildPin(THREE)

      this.clock = new THREE.Clock()
      this.introComplete = false
      this.introT = 0
      this.heroRevealed = false
      this.pinDrop = 0
      this.mode = "plain"
      this.rotation = null
      this.alert = 0
      this.frosted = false
      this.animate()

      this.resizeHandler = this.onResize.bind(this)
      window.addEventListener("resize", this.resizeHandler)
      window.addEventListener("orientationchange", this.resizeHandler)
      if (!this.isMobile) this._bindMouse()

      this.progressHandler = (event) => { if (event.detail) this.story = event.detail }
      window.addEventListener(this.progressEventValue, this.progressHandler)
      window.dispatchEvent(new CustomEvent("landing:sync"))

      this.visibilityHandler = this.onVisibilityChange.bind(this)
      document.addEventListener("visibilitychange", this.visibilityHandler)

      this.themeObserver = new MutationObserver(() => this.onThemeChange())
      this.themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] })
    } catch (e) {
      console.warn("Hero scene init failed:", e)
      this.teardownScene()
      this.showFallback()
    }
  }

  // ── Renderer sizing ───────────────────────────────────────────────────

  _applyRendererSize() {
    if (!this.renderer) return
    const w = Math.min(window.innerWidth, MAX_RENDER_W)
    const h = Math.min(window.innerHeight, MAX_RENDER_H)
    this.renderer.setSize(w, h, false)
    this.renderer.domElement.style.width = "100%"
    this.renderer.domElement.style.height = "100%"
  }

  _chooseRendererPixelRatio() {
    const dpr = window.devicePixelRatio || 1
    if (this.isMobile) return Math.min(dpr, 1.5)
    if (window.matchMedia("(pointer: coarse)").matches) return Math.min(dpr, 1.75)
    return Math.min(dpr, 2)
  }

  _bindMouse() {
    if (this.mouseMoveHandler) return
    this.mouseMoveHandler = this.onMouseMove.bind(this)
    window.addEventListener("mousemove", this.mouseMoveHandler)
  }

  _unbindMouse() {
    if (!this.mouseMoveHandler) return
    window.removeEventListener("mousemove", this.mouseMoveHandler)
    this.mouseMoveHandler = null
    if (this.mouse) { this.mouse.x = 0; this.mouse.y = 0 }
  }

  // ── Scene building ────────────────────────────────────────────────────

  buildLights(THREE) {
    this.hemi = new THREE.HemisphereLight(this.palette.sky, this.palette.ground, HEMI_INTENSITY)
    this.sun = new THREE.DirectionalLight(this.palette.sun, SUN_INTENSITY)
    this.sun.position.set(12, 16, 8)
    this.scene.add(this.hemi, this.sun)
  }

  // Rolling ground with one vertex colour per field patch; hedgerows between.
  buildGround(THREE) {
    const segments = this.isMobile ? 60 : 120
    const geometry = new THREE.PlaneGeometry(WORLD, WORLD, segments, segments)
    geometry.rotateX(-Math.PI / 2)
    const pos = geometry.attributes.position
    const count = pos.count
    this.vertexPatch = new Int8Array(count)
    this.vertexShade = new Float32Array(count)
    this.colorTarget = new Float32Array(count * 3)
    for (let i = 0; i < count; i++) {
      const x = pos.getX(i), z = pos.getZ(i)
      pos.setY(i, height(x, z))
      this.vertexPatch[i] = nearEdge(x, z) ? -1 : patchAt(x, z)
      this.vertexShade[i] = 0.92 + hash(x * 3.1, z * 2.7) * 0.08
    }
    geometry.computeVertexNormals()
    geometry.setAttribute("color", new THREE.BufferAttribute(new Float32Array(count * 3), 3))
    const material = new THREE.MeshLambertMaterial({ vertexColors: true, transparent: true, opacity: 0 })
    this.ground = new THREE.Mesh(geometry, material)
    this.group.add(this.ground)
    this.recolorGround(true)
  }

  // One plant per instance, in rows across every patch; thinned to a budget.
  buildCrops(THREE) {
    const budget = this.isMobile ? 2000 : 6000
    const half = WORLD / 2
    const candidates = []
    for (let z = -half + HEDGE + 0.3; z < half - HEDGE; z += 0.55) {
      for (let x = -half + HEDGE + 0.3; x < half - HEDGE; x += 0.45) {
        if (nearEdge(x, z)) continue
        const jx = (hash(x, z) - 0.5) * 0.25, jz = (hash(z, x) - 0.5) * 0.25
        candidates.push({ x: x + jx, z: z + jz, patch: patchAt(x, z), seed: hash(x * 1.7, z * 1.3) })
      }
    }
    const stride = Math.max(1, Math.ceil(candidates.length / budget))
    this.plants = candidates.filter((_, i) => i % stride === 0)
    const count = this.plants.length

    const geometry = new THREE.ConeGeometry(0.11, 0.7, 5, 1, true)
    geometry.translate(0, 0.35, 0)
    const material = new THREE.MeshLambertMaterial({ transparent: true, opacity: 0 })
    this.crops = new THREE.InstancedMesh(geometry, material, count)
    this.crops.instanceMatrix.setUsage(THREE.DynamicDrawUsage)
    this.plantScale = new Float32Array(count)
    this.plantTarget = new Float32Array(count)
    for (let i = 0; i < count; i++) {
      const plant = this.plants[i]
      plant.y = height(plant.x, plant.z)
      const s = this.plantTargetScale(plant)
      this.plantScale[i] = s
      this.plantTarget[i] = s
      this.composePlant(i, s)
      this.crops.setColorAt(i, this._tmpColor.setHex(this.palette[this.patchCrop[plant.patch]]))
    }
    this.crops.instanceMatrix.needsUpdate = true
    this.crops.instanceColor.needsUpdate = true
    this.group.add(this.crops)
  }

  plantTargetScale(plant) {
    const crop = this.barePatches.has(plant.patch) ? "bare" : this.patchCrop[plant.patch]
    return CROP_SCALE[crop] * (0.85 + plant.seed * 0.3)
  }

  composePlant(i, s) {
    const plant = this.plants[i]
    this._tmpMatrix.makeScale(0.6 + s * 0.4, s, 0.6 + s * 0.4)
    this._tmpMatrix.setPosition(plant.x, plant.y, plant.z)
    this.crops.setMatrixAt(i, this._tmpMatrix)
  }

  // The farmer's pin: head, needle and a pulsing ring on the ground.
  buildPin(THREE) {
    this.pinGround = height(0, 0)
    this.pin = new THREE.Group()
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.45, 16, 12), new THREE.MeshLambertMaterial({ color: this.palette.pin, transparent: true, opacity: 0 }))
    head.position.y = 1.5
    const needle = new THREE.Mesh(new THREE.ConeGeometry(0.28, 1.3, 12), new THREE.MeshLambertMaterial({ color: this.palette.pin, transparent: true, opacity: 0 }))
    needle.rotation.x = Math.PI
    needle.position.y = 0.65
    this.pinMaterials = [head.material, needle.material]
    this.pin.add(head, needle)
    this.pin.position.set(0, this.pinGround + 10, 0)
    this.pin.visible = false

    this.pinRing = new THREE.Mesh(
      new THREE.RingGeometry(0.6, 0.78, 40),
      new THREE.MeshBasicMaterial({ color: this.palette.ring, transparent: true, opacity: 0, depthWrite: false, side: THREE.DoubleSide })
    )
    this.pinRing.rotation.x = -Math.PI / 2
    this.pinRing.position.set(0, this.pinGround + 0.05, 0)
    this.pinRing.visible = false
    this.group.add(this.pin, this.pinRing)
  }

  // ── Colouring ─────────────────────────────────────────────────────────

  // Fills colorTarget from the crop (and tint) of every patch; the loop eases
  // the live attribute toward it. `immediate` copies straight in.
  recolorGround(immediate = false) {
    const attr = this.ground.geometry.attributes.color
    const color = this._tmpColor
    for (let i = 0; i < this.vertexPatch.length; i++) {
      const patch = this.vertexPatch[i]
      if (patch < 0) {
        color.setHex(this.palette.hedge)
      } else {
        color.setHex(this.palette[this.patchCrop[patch]])
        const tint = this.patchTint[patch]
        if (tint) color.lerp(this._tmpColor2.setHex(tint.hex), tint.amount)
      }
      const shade = this.vertexShade[i]
      this.colorTarget[i * 3] = color.r * shade
      this.colorTarget[i * 3 + 1] = color.g * shade
      this.colorTarget[i * 3 + 2] = color.b * shade
    }
    if (immediate) attr.array.set(this.colorTarget)
    attr.needsUpdate = true
    this.colorsDirty = !immediate
  }

  refreshPlants() {
    for (let i = 0; i < this.plants.length; i++) {
      const plant = this.plants[i]
      this.plantTarget[i] = this.plantTargetScale(plant)
      this.crops.setColorAt(i, this._tmpColor.setHex(this.palette[this.patchCrop[plant.patch]]))
    }
    this.crops.instanceColor.needsUpdate = true
    this.plantsDirty = true
  }

  // Rebuilds crops and tints for the current mode, rotation and frost state.
  applyMode() {
    this.patchCrop = LAYOUT.slice()
    this.patchTint.fill(null)
    this.barePatches.clear()
    if (this.mode === "focus") {
      this.patchTint[CENTER] = { hex: this.palette.highlight, amount: 0.55 }
      NEIGHBOURS.forEach((p) => {
        this.patchTint[p] = { hex: this.palette.soil, amount: 0.4 }
        this.barePatches.add(p)
      })
    } else if (this.mode === "history") {
      this.patchTint[CENTER] = { hex: this.palette.highlight, amount: 0.25 }
    } else if (this.mode === "rotation" && this.rotation) {
      Object.entries(ROTATIONS[this.rotation]).forEach(([p, crop]) => { this.patchCrop[Number(p)] = crop })
    }
    if (this.frosted) OUTER.forEach((p) => { this.patchTint[p] = { hex: this.palette.frost, amount: 0.5 } })
    this.recolorGround()
    this.refreshPlants()
  }

  // Light and ring follow the alert amount; frost tints the outer fields past half.
  applyAlert() {
    const k = this.alert
    this.sun.color.setHex(this.palette.sun).lerp(this._tmpColor.setHex(this.palette.sunAlert), k)
    this.sun.intensity = lerp(SUN_INTENSITY, SUN_INTENSITY * 0.65, k)
    this.hemi.intensity = lerp(HEMI_INTENSITY, HEMI_INTENSITY * 0.7, k)
    this.pinRing.material.color.setHex(this.palette.ring).lerp(this._tmpColor.setHex(this.palette.warning), k)
    const frosted = k > 0.5
    if (frosted !== this.frosted) {
      this.frosted = frosted
      this.applyMode()
    }
  }

  // ── Animation loop ────────────────────────────────────────────────────

  animate() {
    if (!this._connected || this._sceneDown) return
    this.animationId = requestAnimationFrame(this.animate.bind(this))
    if (this.paused || !this.renderer) return
    try {
      this.tick()
    } catch (e) {
      console.warn("Hero scene stopped:", e)
      this.teardownScene()
      this.showFallback()
    }
  }

  tick() {
    const dt = Math.min(0.05, this.clock.getDelta())
    const elapsed = this.clock.elapsedTime

    if (!this.introComplete) {
      this.animateIntro(elapsed)
      if (elapsed >= INTRO_DURATION) this.finishIntro()
    }

    this.applyStory(dt, elapsed)
    this.updateCamera(elapsed)
    this.updateGroundColors()
    this.updatePlants()
    this.renderer.render(this.scene, this.camera)
  }

  animateIntro(elapsed) {
    this.introT = easeOutCubic(elapsed / INTRO_DURATION)
    this.ground.material.opacity = this.introT
    this.crops.material.opacity = this.introT
    if (!this.heroRevealed && elapsed >= REVEAL_AT) {
      this.heroRevealed = true
      this.revealHeroContent()
    }
  }

  finishIntro() {
    this.introComplete = true
    this.introT = 1
    ;[this.ground.material, this.crops.material].forEach((material) => {
      material.opacity = 1
      material.transparent = false
      material.needsUpdate = true
    })
  }

  applyStory(dt, elapsed) {
    const { step, progress } = this.story

    // The pin drops once the reader reaches step 1 and stays put.
    const wantPin = step > 1 || (step === 1 && progress >= 0.15)
    if (wantPin && this.pinDrop < 1) {
      this.pin.visible = true
      this.pinDrop = Math.min(1, this.pinDrop + dt / 0.7)
      const t = easeOutCubic(this.pinDrop)
      this.pin.position.y = lerp(this.pinGround + 10, this.pinGround, t) + Math.sin(Math.PI * t) * 0.3 * (1 - t)
      this.pinMaterials.forEach((material) => { material.opacity = t })
      if (this.pinDrop >= 1) this.pinRing.visible = true
    }
    if (this.pinRing.visible) {
      const phase = (elapsed * (0.9 + this.alert * 0.9)) % 1
      const s = 1 + phase * 1.8
      this.pinRing.scale.set(s, s, 1)
      this.pinRing.material.opacity = 0.6 * (1 - phase)
    }

    // Field colouring per step.
    const mode = step === 2 ? "focus" : step === 3 ? "history" : step === 4 ? "rotation" : "plain"
    const rotation = step === 4 ? ROTATION_ORDER[Math.min(2, Math.floor(progress * 3))] : null
    if (mode !== this.mode || rotation !== this.rotation) {
      this.mode = mode
      this.rotation = rotation
      this.applyMode()
    }

    // Alerts: the light goes warm and low, frost creeps over the outer fields.
    const alertTarget = step === 5 ? smoothstep(progress * 1.5) : 0
    const previous = this.alert
    this.alert += (alertTarget - this.alert) * 0.05
    if (Math.abs(this.alert - previous) > 0.0005) this.applyAlert()

    // Canvas opacity: strong in the hero, calmer behind the tour, faint at the download.
    let opacity = 0.85
    if (step === 0) opacity = 1 - easeOutCubic(this.story.heroProgress) * 0.25
    else if (step >= CAMERA.length - 1) opacity = lerp(0.85, 0.35, progress)
    this.renderer.domElement.style.opacity = String(opacity)
  }

  updateCamera(elapsed) {
    const { step, progress } = this.story
    const from = CAMERA[Math.min(step, CAMERA.length - 1)]
    const to = CAMERA[Math.min(step + 1, CAMERA.length - 1)]
    const t = smoothstep(progress)
    const target = this._tmpVec.set(
      lerp(from.pos[0], to.pos[0], t), lerp(from.pos[1], to.pos[1], t), lerp(from.pos[2], to.pos[2], t)
    )
    if (step === 0) {
      // Hero: a slow drift, plus mouse parallax on desktop.
      this.smoothMouse.x += (this.mouse.x - this.smoothMouse.x) * 0.05
      this.smoothMouse.y += (this.mouse.y - this.smoothMouse.y) * 0.05
      target.x += Math.sin(elapsed * 0.15) * 1.2 + this.smoothMouse.x * 1.5
      target.y += Math.cos(elapsed * 0.11) * 0.4 + this.smoothMouse.y * 0.6
      if (!this.introComplete) {
        target.set(lerp(INTRO_FROM[0], target.x, this.introT), lerp(INTRO_FROM[1], target.y, this.introT), lerp(INTRO_FROM[2], target.z, this.introT))
      }
    }
    this.camera.position.lerp(target, this.introComplete ? 0.06 : 0.2)
    this._tmpVec.set(lerp(from.look[0], to.look[0], t), lerp(from.look[1], to.look[1], t), lerp(from.look[2], to.look[2], t))
    this.look.lerp(this._tmpVec, 0.06)
    this.camera.lookAt(this.look)
  }

  updateGroundColors() {
    if (!this.colorsDirty) return
    const attr = this.ground.geometry.attributes.color
    const live = attr.array, target = this.colorTarget
    let maxDelta = 0
    for (let i = 0; i < live.length; i++) {
      const d = target[i] - live[i]
      live[i] += d * 0.08
      const magnitude = Math.abs(d)
      if (magnitude > maxDelta) maxDelta = magnitude
    }
    if (maxDelta < 0.002) {
      live.set(target)
      this.colorsDirty = false
    }
    attr.needsUpdate = true
  }

  updatePlants() {
    if (!this.plantsDirty) return
    let maxDelta = 0
    for (let i = 0; i < this.plants.length; i++) {
      const d = this.plantTarget[i] - this.plantScale[i]
      const magnitude = Math.abs(d)
      if (magnitude < 0.0005) continue
      if (magnitude > maxDelta) maxDelta = magnitude
      this.plantScale[i] = magnitude < 0.004 ? this.plantTarget[i] : this.plantScale[i] + d * 0.08
      this.composePlant(i, this.plantScale[i])
    }
    this.crops.instanceMatrix.needsUpdate = true
    if (maxDelta < 0.004) this.plantsDirty = false
  }

  // ── Hero content reveal and fallback ──────────────────────────────────

  revealHeroContent() {
    if (this.revealTimer) { clearTimeout(this.revealTimer); this.revealTimer = null }
    if (!this._revealed) {
      this._revealed = true
      // The mascot preloader waits for this before leaving the centre.
      window.dispatchEvent(new CustomEvent("hero:revealed"))
    }
    if (!this.hasHeroContentTarget) return
    if (this.hasHiddenClass) this.heroContentTarget.classList.remove(this.hiddenClass)
    if (this.hasVisibleClass) this.heroContentTarget.classList.add(this.visibleClass)
  }

  // The CSS backdrop stands in for the scene (reduced motion, no WebGL, a crash).
  showFallback() {
    if (this.hasFallbackClass && this.hasCanvasTarget) this.canvasTarget.classList.add(this.fallbackClass)
    this.revealHeroContent()
  }

  // ── Event handlers ────────────────────────────────────────────────────

  onMouseMove(e) {
    this.mouse.x = (e.clientX / window.innerWidth - 0.5) * 2
    this.mouse.y = -(e.clientY / window.innerHeight - 0.5) * 2
  }

  onResize() {
    if (this._resizeRaf) cancelAnimationFrame(this._resizeRaf)
    this._resizeRaf = requestAnimationFrame(() => this._handleResize())
  }

  _handleResize() {
    if (!this._connected || !this.renderer || !this.camera) return
    const prevMobile = this.isMobile
    this._evaluateDevice()

    this.camera.aspect = window.innerWidth / window.innerHeight
    this.camera.updateProjectionMatrix()
    this._applyRendererSize()
    this.renderer.setPixelRatio(this._chooseRendererPixelRatio())

    if (prevMobile && !this.isMobile) this._bindMouse()
    else if (!prevMobile && this.isMobile) this._unbindMouse()
  }

  onVisibilityChange() {
    if (document.hidden) {
      this.paused = true
      if (this.clock) this.clock.stop()
    } else {
      this.paused = false
      if (this.clock) this.clock.start()
    }
  }

  onThemeChange() {
    const next = this._readTheme()
    if (next === this._currentTheme) return
    this._currentTheme = next
    this.palette = PALETTES[next]
    if (!this.scene) return
    this.scene.fog.color.setHex(this.palette.fog)
    this.hemi.color.setHex(this.palette.sky)
    this.hemi.groundColor.setHex(this.palette.ground)
    this.pinMaterials.forEach((material) => material.color.setHex(this.palette.pin))
    this.applyAlert()
    this.applyMode()
  }

  // ── Cleanup ───────────────────────────────────────────────────────────

  // Stops rendering and frees every GPU resource; safe to call more than once.
  teardownScene() {
    this._sceneDown = true
    if (this.animationId) { cancelAnimationFrame(this.animationId); this.animationId = null }
    if (this.group) {
      this.group.traverse((child) => {
        if (child.geometry) child.geometry.dispose()
        if (child.material) child.material.dispose()
      })
    }
    if (this.renderer) {
      this.renderer.dispose()
      const element = this.renderer.domElement
      if (element && element.parentNode) element.parentNode.removeChild(element)
    }
    this.scene = null
    this.camera = null
    this.renderer = null
    this.group = null
    this.ground = null
    this.crops = null
    this.pin = null
    this.pinRing = null
    this.hemi = null
    this.sun = null
  }

  disconnect() {
    this._connected = false
    if (this.revealTimer) { clearTimeout(this.revealTimer); this.revealTimer = null }
    if (this._resizeRaf) cancelAnimationFrame(this._resizeRaf)
    if (this.resizeHandler) {
      window.removeEventListener("resize", this.resizeHandler)
      window.removeEventListener("orientationchange", this.resizeHandler)
    }
    this._unbindMouse()
    if (this.progressHandler) window.removeEventListener(this.progressEventValue, this.progressHandler)
    if (this.visibilityHandler) document.removeEventListener("visibilitychange", this.visibilityHandler)
    if (this.themeObserver) this.themeObserver.disconnect()
    this.teardownScene()
    this.THREE = null
  }
}
