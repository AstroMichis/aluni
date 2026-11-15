import { Controller } from "@hotwired/stimulus"
import { reducedMotion } from "preferences/motion"

// The field station's product shot on /devices: a portable, solar-topped unit with a
// curved status screen, a carry loop and a stainless soil probe, drawn with Three.js
// (vendored, loaded lazily so only this page pays for it).
//
// - Built from lathe profiles (smooth turned shapes), physical materials and a
//   studio rig (key, rim and fill lights plus a contact shadow). No model files.
// - Turns slowly on its own; drag (pointer) or the arrow keys rotate it. With reduced
//   motion it stays still but can still be turned by hand.
// - "Lite" / "Pro" switch the antenna and the screen's connectivity line.
// - Screen copy comes from data values (t() in the view); the texture draws it.
// - Any failure (no WebGL, import error) keeps the static fallback picture visible.
// - Renders only while on screen and the tab is visible; disconnect() frees every
//   GPU resource, which also covers Turbo navigation.
const COLORS = {
  shell: 0xeee8da,
  shellDark: 0xd9d1bf,
  accent: 0xb69a5b,
  solar: 0x1a2a44,
  solarCell: "#2c4a78",
  steel: 0xc9ccd0,
  band: 0x2b3a33,
  led: 0x8cbf7e,
  screen: "#0f2920",
  screenText: "#f1ebdd",
  screenMuted: "#a4a994",
  screenAccent: "#d9c48f"
}
const AUTO_SPEED = 0.25 // radians per second
const DRAG_SPEED = 0.01
const KEY_STEP = 0.2

export default class extends Controller {
  static targets = ["canvas", "fallback", "model"]
  static values = {
    model: { type: String, default: "pro" },
    brand: { type: String, default: "" },
    soilLabel: { type: String, default: "" },
    airLabel: { type: String, default: "" },
    liteStatus: { type: String, default: "" },
    proStatus: { type: String, default: "" }
  }

  connect() {
    this._connected = true
    this.still = reducedMotion()
    this.init()
  }

  disconnect() {
    this._connected = false
    this.teardown()
  }

  async init() {
    let THREE
    try {
      THREE = await import("three")
    } catch (error) {
      console.warn("[device-viewer]", error)
      return
    }
    if (!this._connected || !this.hasCanvasTarget) return

    try {
      this.THREE = THREE
      const width = this.canvasTarget.clientWidth || 480
      const height = this.canvasTarget.clientHeight || 480
      this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "low-power" })
      this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2))
      this.renderer.setSize(width, height)
      this.renderer.outputColorSpace = THREE.SRGBColorSpace
      this.renderer.toneMapping = THREE.ACESFilmicToneMapping
      this.renderer.toneMappingExposure = 1.05
      this.renderer.domElement.setAttribute("aria-hidden", "true")

      this.scene = new THREE.Scene()
      this.camera = new THREE.PerspectiveCamera(30, width / height, 0.1, 100)
      this.camera.position.set(0, 0.3, 12.8)
      this.camera.lookAt(0, -1.0, 0)

      this.buildLights(THREE)
      this.buildEnvironment(THREE)
      this.device = new THREE.Group()
      this.device.rotation.set(0.1, -0.45, 0) // the screen turns into view as it spins
      this.device.scale.set(0.88, 1, 0.88) // slimmer than turned: a portable flask, not a can
      this.scene.add(this.device)
      this.buildBody(THREE)
      this.buildSolarCap(THREE)
      this.buildScreen(THREE)
      this.buildDetails(THREE)
      this.buildProbe(THREE)
      this.buildAntenna(THREE)
      this.buildShadow(THREE)
      this.applyModel()

      this.canvasTarget.appendChild(this.renderer.domElement)
      if (this.hasFallbackTarget) this.fallbackTarget.hidden = true
      this.canvasTarget.classList.add("device-viewer__canvas--live")

      this.bindEvents()
      // The screen uses the site fonts; redraw once they are ready.
      if (document.fonts && document.fonts.ready) {
        document.fonts.ready.then(() => { if (this.device) this.applyModel() })
      }
      this.clock = new THREE.Clock()
      this.requestRender()
      this.loop()
    } catch (error) {
      console.warn("[device-viewer]", error)
      this.teardown()
      if (this.hasFallbackTarget) this.fallbackTarget.hidden = false
    }
  }

  // ── Model ─────────────────────────────────────────────────────────────

  buildLights(THREE) {
    this.scene.add(new THREE.HemisphereLight(0xfff8ec, 0x24382f, 0.55))
    const key = new THREE.DirectionalLight(0xffffff, 2.0)
    key.position.set(4, 6, 6)
    this.scene.add(key)
    const rim = new THREE.DirectionalLight(0xd9c48f, 1.8)
    rim.position.set(-5, 3, -4)
    this.scene.add(rim)
    const fill = new THREE.DirectionalLight(0x93aacb, 0.6)
    fill.position.set(-4, -1, 5)
    this.scene.add(fill)
  }

// A tiny studio for reflections (metal and glass need something to mirror): a
  // gradient dome with two soft light panels, baked once through PMREM.
  buildEnvironment(THREE) {
    const studio = new THREE.Scene()
    const dome = new THREE.Mesh(
      new THREE.SphereGeometry(10, 32, 16),
      new THREE.ShaderMaterial({
        side: THREE.BackSide,
        uniforms: { top: { value: new THREE.Color(0xf3efe6) }, bottom: { value: new THREE.Color(0x1d3a2e) } },
        vertexShader: "varying vec3 vPos; void main() { vPos = position; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }",
        fragmentShader: "uniform vec3 top; uniform vec3 bottom; varying vec3 vPos; void main() { float h = normalize(vPos).y * 0.5 + 0.5; gl_FragColor = vec4(mix(bottom, top, smoothstep(0.2, 0.9, h)), 1.0); }"
      })
    )
    studio.add(dome)
    const panel = new THREE.MeshBasicMaterial({ color: 0xffffff })
    const softbox = new THREE.Mesh(new THREE.PlaneGeometry(6, 3), panel)
    softbox.position.set(4, 5, 6)
    softbox.lookAt(0, 0, 0)
    const strip = new THREE.Mesh(new THREE.PlaneGeometry(1.2, 8), panel)
    strip.position.set(-7, 1, -2)
    strip.lookAt(0, 0, 0)
    studio.add(softbox, strip)
    const pmrem = new THREE.PMREMGenerator(this.renderer)
    this.envTarget = pmrem.fromScene(studio, 0.04)
    this.scene.environment = this.envTarget.texture
    pmrem.dispose()
    studio.traverse((child) => {
      if (child.geometry) child.geometry.dispose()
      if (child.material) child.material.dispose()
    })
  }

  // The housing: a turned capsule, slightly waisted, with a soft shoulder.
  buildBody(THREE) {
    const p = (x, y) => new THREE.Vector2(x, y)
    const profile = [
      p(0, -1.3), p(0.6, -1.3), p(0.84, -1.23), p(0.94, -1.08), p(0.97, -0.7),
      p(0.93, 0.15), p(0.96, 0.95), p(0.98, 1.08), p(0.93, 1.17), p(0.8, 1.2), p(0, 1.2)
    ]
    const shell = new THREE.MeshPhysicalMaterial({ color: COLORS.shell, roughness: 0.42, clearcoat: 0.35, clearcoatRoughness: 0.4 })
    const body = new THREE.Mesh(new THREE.LatheGeometry(profile, 96), shell)
    this.device.add(body)

    // The accent waistband and the darker base ring that meets the probe.
    const accent = new THREE.MeshStandardMaterial({ color: COLORS.accent, metalness: 0.75, roughness: 0.32 })
    const band = new THREE.Mesh(new THREE.TorusGeometry(0.955, 0.035, 16, 120), accent)
    band.rotation.x = Math.PI / 2
    band.position.y = -0.2
    this.device.add(band)

    const base = new THREE.Mesh(
      new THREE.CylinderGeometry(0.66, 0.6, 0.16, 64),
      new THREE.MeshStandardMaterial({ color: COLORS.shellDark, roughness: 0.6 })
    )
    base.position.y = -1.36
    this.device.add(base)
  }

  // A round solar cell under a glass top, with a thin metal rim.
  buildSolarCap(THREE) {
    const texture = this.solarTexture(THREE)
    const glass = new THREE.MeshPhysicalMaterial({ map: texture, color: 0xffffff, metalness: 0.2, roughness: 0.15, clearcoat: 1, clearcoatRoughness: 0.05 })
    const cap = new THREE.Mesh(new THREE.CylinderGeometry(0.8, 0.8, 0.04, 96), [
      new THREE.MeshStandardMaterial({ color: COLORS.solar, roughness: 0.4 }), glass, glass
    ])
    cap.position.y = 1.215
    this.device.add(cap)

    const rim = new THREE.Mesh(
      new THREE.TorusGeometry(0.81, 0.025, 12, 120),
      new THREE.MeshStandardMaterial({ color: COLORS.steel, metalness: 0.9, roughness: 0.25 })
    )
    rim.rotation.x = Math.PI / 2
    rim.position.y = 1.235
    this.device.add(rim)
  }

  solarTexture(THREE) {
    const size = 512
    const canvas = document.createElement("canvas")
    canvas.width = canvas.height = size
    const ctx = canvas.getContext("2d")
    ctx.fillStyle = "#13203a"
    ctx.fillRect(0, 0, size, size)
    const cell = size / 8
    for (let i = 0; i < 8; i++) {
      for (let j = 0; j < 8; j++) {
        const gradient = ctx.createLinearGradient(i * cell, j * cell, (i + 1) * cell, (j + 1) * cell)
        gradient.addColorStop(0, COLORS.solarCell)
        gradient.addColorStop(1, "#1a2f55")
        ctx.fillStyle = gradient
        ctx.fillRect(i * cell + 3, j * cell + 3, cell - 6, cell - 6)
      }
    }
    ctx.strokeStyle = "rgba(220, 230, 255, 0.25)"
    ctx.lineWidth = 1
    for (let k = 1; k < 4; k++) {
      ctx.beginPath()
      ctx.moveTo(0, (k * size) / 4)
      ctx.lineTo(size, (k * size) / 4)
      ctx.stroke()
    }
    const texture = new THREE.CanvasTexture(canvas)
    texture.colorSpace = THREE.SRGBColorSpace
    return texture
  }

  // The curved status screen: a slice of a cylinder just outside the shell.
  buildScreen(THREE) {
    this.screenCanvas = document.createElement("canvas")
    this.screenCanvas.width = 512
    this.screenCanvas.height = 384
    this.screenTexture = new THREE.CanvasTexture(this.screenCanvas)
    this.screenTexture.colorSpace = THREE.SRGBColorSpace
    const arc = 1.55
    const geometry = new THREE.CylinderGeometry(0.975, 0.975, 0.92, 64, 1, true, -arc / 2, arc)
    const screen = new THREE.Mesh(
      geometry,
      new THREE.MeshPhysicalMaterial({ map: this.screenTexture, roughness: 0.2, clearcoat: 1, clearcoatRoughness: 0.08, side: THREE.FrontSide })
    )
    screen.position.y = 0.45
    this.device.add(screen)

    const bezel = new THREE.Mesh(
      new THREE.CylinderGeometry(0.972, 0.972, 1.0, 64, 1, true, -arc / 2 - 0.05, arc + 0.1),
      new THREE.MeshStandardMaterial({ color: 0x1b2a24, roughness: 0.5 })
    )
    bezel.position.y = 0.45
    this.device.add(bezel)
  }

  drawScreen() {
    const ctx = this.screenCanvas.getContext("2d")
    const { width: w, height: h } = this.screenCanvas
    ctx.fillStyle = COLORS.screen
    ctx.fillRect(0, 0, w, h)
    ctx.textBaseline = "alphabetic"
    ctx.textAlign = "left"

    ctx.fillStyle = COLORS.screenAccent
    ctx.font = "600 34px Inter, system-ui, sans-serif"
    ctx.fillText(this.brandValue, 60, 70)
    ctx.fillStyle = COLORS.screenMuted
    ctx.font = "500 24px Inter, system-ui, sans-serif"
    ctx.textAlign = "right"
    ctx.fillText(this.modelValue === "pro" ? this.proStatusValue : this.liteStatusValue, w - 60, 70)

    ctx.textAlign = "left"
    ctx.fillStyle = COLORS.screenMuted
    ctx.font = "500 26px Inter, system-ui, sans-serif"
    ctx.fillText(this.soilLabelValue, 60, 150)
    ctx.fillText(this.airLabelValue, w / 2 + 20, 150)
    ctx.fillStyle = COLORS.screenText
    ctx.font = "600 78px 'JetBrains Mono', ui-monospace, monospace"
    ctx.fillText("31%", 60, 240)
    ctx.fillText("18°", w / 2 + 20, 240)

    // A small soil moisture sparkline.
    ctx.strokeStyle = COLORS.screenAccent
    ctx.lineWidth = 5
    ctx.lineJoin = "round"
    ctx.beginPath()
    const points = [0.55, 0.5, 0.52, 0.3, 0.32, 0.4, 0.46, 0.5, 0.28, 0.3, 0.36, 0.42]
    points.forEach((v, i) => {
      const x = 60 + (i * (w - 120)) / (points.length - 1)
      const y = 280 + v * 80
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    })
    ctx.stroke()
    this.screenTexture.needsUpdate = true
  }

  // Status LED, a QR plate, side vents for the air sensor and the carry loop.
  buildDetails(THREE) {
    this.led = new THREE.Mesh(
      new THREE.SphereGeometry(0.05, 24, 24),
      new THREE.MeshStandardMaterial({ color: COLORS.led, emissive: COLORS.led, emissiveIntensity: 1.6 })
    )
    this.led.position.set(0, -0.45, 0.965)
    this.device.add(this.led)

    const qr = new THREE.Mesh(
      new THREE.BoxGeometry(0.22, 0.22, 0.02),
      new THREE.MeshStandardMaterial({ color: 0x1b2a24, roughness: 0.7 })
    )
    qr.position.set(0.32, -0.62, 0.9)
    qr.rotation.y = 0.33
    this.device.add(qr)

    const ventMaterial = new THREE.MeshStandardMaterial({ color: 0x8f8a7c, roughness: 0.8 })
    for (let i = 0; i < 4; i++) {
      const vent = new THREE.Mesh(new THREE.BoxGeometry(0.035, 0.36, 0.06), ventMaterial)
      const angle = Math.PI * 0.62 + i * 0.13
      vent.position.set(Math.sin(angle) * 0.955, 0.45, Math.cos(angle) * 0.955)
      vent.rotation.y = angle
      this.device.add(vent)
    }

    const loop = new THREE.Mesh(
      new THREE.TorusGeometry(0.34, 0.05, 16, 64, Math.PI),
      new THREE.MeshPhysicalMaterial({ color: 0x2b3a33, roughness: 0.55, clearcoat: 0.2 })
    )
    loop.position.set(0, 1.24, -0.45)
    loop.rotation.y = Math.PI / 2
    this.device.add(loop)
  }

  // The stainless stake: threaded collar, two sensor bands (10 and 30 cm) and a tip.
  buildProbe(THREE) {
    const p = (x, y) => new THREE.Vector2(x, y)
    const profile = [
      p(0, -4.1), p(0.04, -3.92), p(0.13, -3.6), p(0.15, -3.3), p(0.15, -1.75),
      p(0.24, -1.62), p(0.26, -1.48), p(0.3, -1.44), p(0, -1.44)
    ]
    const steel = new THREE.MeshPhysicalMaterial({ color: COLORS.steel, metalness: 0.95, roughness: 0.22, clearcoat: 0.3 })
    const probe = new THREE.Mesh(new THREE.LatheGeometry(profile, 64), steel)
    this.device.add(probe)

    const bandMaterial = new THREE.MeshStandardMaterial({ color: COLORS.band, roughness: 0.5 })
    ;[-2.35, -3.05].forEach((y) => {
      const band = new THREE.Mesh(new THREE.CylinderGeometry(0.158, 0.158, 0.18, 48), bandMaterial)
      band.position.y = y
      this.device.add(band)
    })
  }

  // The Pro's cellular antenna, on the shoulder next to the solar cap.
  buildAntenna(THREE) {
    this.antenna = new THREE.Group()
    const rod = new THREE.Mesh(
      new THREE.CylinderGeometry(0.045, 0.06, 0.75, 24),
      new THREE.MeshPhysicalMaterial({ color: 0x2b3a33, roughness: 0.5, clearcoat: 0.3 })
    )
    rod.position.y = 0.375
    const tip = new THREE.Mesh(
      new THREE.SphereGeometry(0.06, 24, 24),
      new THREE.MeshStandardMaterial({ color: COLORS.accent, metalness: 0.7, roughness: 0.3 })
    )
    tip.position.y = 0.76
    this.antenna.add(rod, tip)
    this.antenna.position.set(0.62, 1.12, -0.3)
    this.antenna.rotation.z = -0.12
    this.device.add(this.antenna)
  }

  // A soft contact shadow under the probe tip, drawn once on a canvas.
  buildShadow(THREE) {
    const canvas = document.createElement("canvas")
    canvas.width = canvas.height = 128
    const ctx = canvas.getContext("2d")
    const gradient = ctx.createRadialGradient(64, 64, 0, 64, 64, 64)
    gradient.addColorStop(0, "rgba(0, 0, 0, 0.45)")
    gradient.addColorStop(1, "rgba(0, 0, 0, 0)")
    ctx.fillStyle = gradient
    ctx.fillRect(0, 0, 128, 128)
    const shadow = new THREE.Mesh(
      new THREE.PlaneGeometry(2.6, 2.6),
      new THREE.MeshBasicMaterial({ map: new THREE.CanvasTexture(canvas), transparent: true, depthWrite: false })
    )
    shadow.rotation.x = -Math.PI / 2
    shadow.position.y = -4.15
    this.scene.add(shadow)
  }

  // ── Interaction ───────────────────────────────────────────────────────

  selectModel(event) {
    const model = event.params.model
    if (!model || model === this.modelValue) return
    this.modelValue = model
  }

  modelValueChanged() {
    this.modelTargets.forEach((button) => button.setAttribute("aria-pressed", String(button.dataset.deviceViewerModelParam === this.modelValue)))
    this.applyModel()
  }

  applyModel() {
    if (!this.device) return
    if (this.antenna) this.antenna.visible = this.modelValue === "pro"
    this.drawScreen()
    this.requestRender()
  }

  rotateWithKeys(event) {
    if (!this.device) return
    if (event.key === "ArrowLeft") this.device.rotation.y -= KEY_STEP
    else if (event.key === "ArrowRight") this.device.rotation.y += KEY_STEP
    else return
    event.preventDefault()
    this.requestRender()
  }

  bindEvents() {
    const element = this.renderer.domElement
    this.onPointerDown = (event) => {
      this.dragging = { x: event.clientX, y: event.clientY }
      element.setPointerCapture(event.pointerId)
    }
    this.onPointerMove = (event) => {
      if (!this.dragging) return
      this.device.rotation.y += (event.clientX - this.dragging.x) * DRAG_SPEED
      this.device.rotation.x = Math.max(-0.4, Math.min(0.5, this.device.rotation.x + (event.clientY - this.dragging.y) * DRAG_SPEED * 0.5))
      this.dragging = { x: event.clientX, y: event.clientY }
      this.requestRender()
    }
    this.onPointerUp = () => { this.dragging = null }
    element.addEventListener("pointerdown", this.onPointerDown)
    element.addEventListener("pointermove", this.onPointerMove)
    element.addEventListener("pointerup", this.onPointerUp)
    element.addEventListener("pointercancel", this.onPointerUp)

    this.onResize = () => {
      if (!this.renderer) return
      const width = this.canvasTarget.clientWidth
      const height = this.canvasTarget.clientHeight
      if (!width || !height) return
      this.renderer.setSize(width, height)
      this.camera.aspect = width / height
      this.camera.updateProjectionMatrix()
      this.requestRender()
    }
    window.addEventListener("resize", this.onResize)

    this.visible = true
    this.observer = new IntersectionObserver(([entry]) => { this.visible = entry.isIntersecting })
    this.observer.observe(this.canvasTarget)
  }

  // ── Rendering ─────────────────────────────────────────────────────────

  loop() {
    this.frame = requestAnimationFrame(() => this.loop())
    const delta = this.clock.getDelta()
    if (!this.visible || document.hidden) return
    const spinning = !this.still && !this.dragging
    if (spinning) {
      this.device.rotation.y += AUTO_SPEED * delta
      this.led.material.emissiveIntensity = 1.2 + Math.sin(this.clock.elapsedTime * 2.2) * 0.5
    }
    if (spinning || this.needsRender) {
      this.needsRender = false
      this.renderer.render(this.scene, this.camera)
    }
  }

  requestRender() {
    this.needsRender = true
  }

  teardown() {
    if (this.frame) cancelAnimationFrame(this.frame)
    if (this.observer) this.observer.disconnect()
    if (this.onResize) window.removeEventListener("resize", this.onResize)
    if (this.scene) {
      this.scene.traverse((child) => {
        if (child.geometry) child.geometry.dispose()
        const materials = Array.isArray(child.material) ? child.material : [child.material]
        materials.filter(Boolean).forEach((material) => {
          if (material.map) material.map.dispose()
          material.dispose()
        })
      })
    }
    if (this.renderer) {
      this.renderer.dispose()
      const element = this.renderer.domElement
      if (element && element.parentNode) element.parentNode.removeChild(element)
    }
    if (this.envTarget) this.envTarget.dispose()
    this.scene = this.camera = this.renderer = this.device = this.envTarget = null
  }
}
