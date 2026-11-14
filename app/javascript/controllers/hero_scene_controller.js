import { Controller } from "@hotwired/stimulus"

// The landing hero's background scene: a slowly turning sphere of points with
// three orbit rings, drawn with Three.js (vendored, loaded lazily so only this
// page pays for it). The scene is the signature of the site, nothing more:
// it recedes as the page scrolls and never blocks the copy.
//
// Lifecycle rules (keep when changing the geometry):
// - prefers-reduced-motion: reveal the copy, never import Three.
// - any failure (no WebGL, import error): warn and reveal the copy.
// - resize/orientation debounced through rAF; clock paused when hidden.
// - theme palette follows html[data-theme] live through a MutationObserver.
// - disconnect() removes every listener and disposes every GPU resource,
//   which also covers Turbo navigation.

const MAX_RENDER_W = 2560
const MAX_RENDER_H = 1440
const INTRO_DURATION = 2.4
const REVEAL_AT = 0.9

const PALETTES = {
  dark:  { points: 0x5B8DEF, rings: 0x2E3A55, accent: 0xE0A458 },
  light: { points: 0x2F67D8, rings: 0xC3CDE0, accent: 0xB87A24 }
}
const THEME_OPACITY_SCALE = { dark: 1.0, light: 0.8 }

const easeOutCubic = (t) => 1 - Math.pow(1 - Math.min(1, Math.max(0, t)), 3)

export default class extends Controller {
  static targets = ["canvas", "heroContent"]
  // The view passes its own BEM classes (data-hero-scene-hidden-class /
  // -visible-class) so the controller stays layout-agnostic.
  static classes = ["hidden", "visible"]

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.revealHeroContent()
      return
    }
    this._connected = true
    this.paused = false
    this.mouse = { x: 0, y: 0 }
    this.smoothMouse = { x: 0, y: 0 }
    this.materialsByRole = { points: [], rings: [], accent: [] }
    this._evaluateDevice()
    this._currentTheme = this._readTheme()
    this.palette = PALETTES[this._currentTheme]
    this._opacityScale = THEME_OPACITY_SCALE[this._currentTheme] || 1.0
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

      this.scene = new THREE.Scene()
      this.camera = new THREE.PerspectiveCamera(55, window.innerWidth / window.innerHeight, 0.1, 100)
      this.renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true })
      this._applyRendererSize()
      this.renderer.setPixelRatio(this._chooseRendererPixelRatio())

      if (!this.hasCanvasTarget) { this.revealHeroContent(); return }
      this.canvasTarget.appendChild(this.renderer.domElement)

      this.group = new THREE.Group()
      this.scene.add(this.group)

      this.cameraStartZ = 14
      this.cameraEndZ = 8
      this.camera.position.z = this.cameraStartZ

      this.buildPointSphere(THREE)
      this.buildOrbitRings(THREE)

      this.clock = new THREE.Clock()
      this.introComplete = false
      this.heroRevealed = false
      this.scrollRaw = 0
      this.scrollSmooth = 0
      this.heroScrollProgress = 0
      this.animate()

      this.resizeHandler = this.onResize.bind(this)
      window.addEventListener("resize", this.resizeHandler)
      window.addEventListener("orientationchange", this.resizeHandler)

      if (!this.isMobile) this._bindMouse()

      this.scrollHandler = () => {
        const doc = document.documentElement
        const scrollTop = window.scrollY || doc.scrollTop
        const scrollHeight = doc.scrollHeight - doc.clientHeight
        this.scrollRaw = scrollHeight > 0 ? scrollTop / scrollHeight : 0
        const vh = window.innerHeight || 1
        this.heroScrollProgress = Math.min(1, scrollTop / vh)
      }
      window.addEventListener("scroll", this.scrollHandler, { passive: true })
      this.scrollHandler()

      this.visibilityHandler = this.onVisibilityChange.bind(this)
      document.addEventListener("visibilitychange", this.visibilityHandler)

      this.themeObserver = new MutationObserver(() => this.onThemeChange())
      this.themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] })
    } catch (e) {
      console.warn("Hero scene init failed:", e)
      this.revealHeroContent()
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
    this.mouse.x = 0
    this.mouse.y = 0
  }

  _registerMaterial(role, material) {
    material.userData.role = role
    this.materialsByRole[role].push(material)
    return material
  }

  // ── Geometry ──────────────────────────────────────────────────────────

  // Points spread evenly on a sphere (Fibonacci lattice); fewer on phones.
  buildPointSphere(THREE) {
    const count = this.isMobile ? 900 : 1800
    const radius = 3
    const positions = new Float32Array(count * 3)
    const golden = Math.PI * (3 - Math.sqrt(5))
    for (let i = 0; i < count; i++) {
      const y = 1 - (i / (count - 1)) * 2
      const r = Math.sqrt(1 - y * y)
      const theta = golden * i
      positions[i * 3] = Math.cos(theta) * r * radius
      positions[i * 3 + 1] = y * radius
      positions[i * 3 + 2] = Math.sin(theta) * r * radius
    }
    const geometry = new THREE.BufferGeometry()
    geometry.setAttribute("position", new THREE.BufferAttribute(positions, 3))
    const material = this._registerMaterial("points", new THREE.PointsMaterial({
      color: this.palette.points, size: 0.035, sizeAttenuation: true, transparent: true, opacity: 0, depthWrite: false
    }))
    material.userData.targetOpacity = 0.85
    this.points = new THREE.Points(geometry, material)
    this.group.add(this.points)
  }

  // Three thin orbits at different tilts; one in the accent colour.
  buildOrbitRings(THREE) {
    const segments = 256
    const specs = [
      { radius: 3.6, tilt: [Math.PI / 2.3, 0, 0], role: "rings", opacity: 0.35 },
      { radius: 4.1, tilt: [Math.PI / 3, Math.PI / 5, 0], role: "rings", opacity: 0.25 },
      { radius: 3.3, tilt: [Math.PI / 1.8, -Math.PI / 4, Math.PI / 7], role: "accent", opacity: 0.45 }
    ]
    this.rings = specs.map((spec) => {
      const positions = new Float32Array((segments + 1) * 3)
      for (let i = 0; i <= segments; i++) {
        const a = (i / segments) * Math.PI * 2
        positions[i * 3] = Math.cos(a) * spec.radius
        positions[i * 3 + 1] = 0
        positions[i * 3 + 2] = Math.sin(a) * spec.radius
      }
      const geometry = new THREE.BufferGeometry()
      geometry.setAttribute("position", new THREE.BufferAttribute(positions, 3))
      const material = this._registerMaterial(spec.role, new THREE.LineBasicMaterial({
        color: this.palette[spec.role], transparent: true, opacity: 0, depthWrite: false
      }))
      material.userData.targetOpacity = spec.opacity
      const line = new THREE.Line(geometry, material)
      line.rotation.set(...spec.tilt)
      this.group.add(line)
      return line
    })
  }

  // ── Animation loop ────────────────────────────────────────────────────

  animate() {
    if (!this._connected) return
    this.animationId = requestAnimationFrame(this.animate.bind(this))
    if (this.paused || !this.renderer) return

    const elapsed = this.clock.getElapsedTime()
    this.scrollSmooth += (this.scrollRaw - this.scrollSmooth) * 0.04

    if (!this.introComplete) {
      this.animateIntro(elapsed)
      if (elapsed >= INTRO_DURATION) this.introComplete = true
    }

    // The scene recedes as the copy below the hero takes over.
    const fade = 1 - easeOutCubic(this.heroScrollProgress) * 0.7
    this.renderer.domElement.style.opacity = String(fade)

    this.smoothMouse.x += (this.mouse.x - this.smoothMouse.x) * 0.05
    this.smoothMouse.y += (this.mouse.y - this.smoothMouse.y) * 0.05

    this.group.rotation.y = elapsed * 0.05 + this.scrollSmooth * Math.PI * 0.6 + this.smoothMouse.x * 0.15
    this.group.rotation.x = 0.12 * Math.sin(elapsed * 0.08) + this.scrollSmooth * Math.PI * 0.2 - this.smoothMouse.y * 0.1
    this.rings.forEach((ring, i) => { ring.rotation.z += 0.0004 * (i + 1) })

    this.renderer.render(this.scene, this.camera)
  }

  animateIntro(elapsed) {
    const t = easeOutCubic(elapsed / INTRO_DURATION)
    this.camera.position.z = this.cameraStartZ + (this.cameraEndZ - this.cameraStartZ) * t
    Object.values(this.materialsByRole).flat().forEach((material) => {
      material.opacity = (material.userData.targetOpacity || 0) * t * this._opacityScale
    })
    if (!this.heroRevealed && elapsed >= REVEAL_AT) {
      this.heroRevealed = true
      this.revealHeroContent()
    }
  }

  // ── Hero content reveal ───────────────────────────────────────────────

  revealHeroContent() {
    if (!this.hasHeroContentTarget) return
    if (this.hasHiddenClass) this.heroContentTarget.classList.remove(this.hiddenClass)
    if (this.hasVisibleClass) this.heroContentTarget.classList.add(this.visibleClass)
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
    this._opacityScale = THEME_OPACITY_SCALE[next] || 1.0
    Object.entries(this.materialsByRole).forEach(([role, materials]) => {
      materials.forEach((material) => {
        material.color.setHex(this.palette[role])
        if (this.introComplete) material.opacity = (material.userData.targetOpacity || 0) * this._opacityScale
      })
    })
  }

  // ── Cleanup ───────────────────────────────────────────────────────────

  disconnect() {
    this._connected = false

    if (this.animationId) cancelAnimationFrame(this.animationId)
    if (this._resizeRaf) cancelAnimationFrame(this._resizeRaf)
    if (this.resizeHandler) {
      window.removeEventListener("resize", this.resizeHandler)
      window.removeEventListener("orientationchange", this.resizeHandler)
    }
    this._unbindMouse()
    if (this.scrollHandler) window.removeEventListener("scroll", this.scrollHandler)
    if (this.visibilityHandler) document.removeEventListener("visibilitychange", this.visibilityHandler)
    if (this.themeObserver) this.themeObserver.disconnect()

    if (this.group) {
      this.group.traverse((child) => {
        if (child.geometry) child.geometry.dispose()
        if (child.material) child.material.dispose()
      })
    }

    if (this.renderer) {
      this.renderer.dispose()
      if (this.renderer.domElement && this.renderer.domElement.parentNode) {
        this.renderer.domElement.parentNode.removeChild(this.renderer.domElement)
      }
    }

    this.scene = null
    this.camera = null
    this.renderer = null
    this.group = null
    this.points = null
    this.rings = null
    this.materialsByRole = null
    this.THREE = null
  }
}
