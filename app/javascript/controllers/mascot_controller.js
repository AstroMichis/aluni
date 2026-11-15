import { Controller } from "@hotwired/stimulus"

// Aluni, the seedling mascot: a small Three.js stage (vendored r169, loaded
// lazily next to the mascot/* modules) with an HTML speech bubble. Two modes:
//
//   landing  the stage sits fixed bottom-left, starts offstage, slides in with
//            a CSS transform while the character walks in place, waves, shows
//            the bubble, and later docks (FLIP) into the chat panel's slot.
//   docked   the companion on /app/onboarding: relative in its container, no
//            entrance, idle from the start, no bubble.
//
// Events on window. Dispatched: mascot:ready, mascot:arrived, mascot:docked
// { handoff: "canvas" | "svg" }, mascot:fallback, mascot:lets-go. Listened:
// mascot:speak { chars }, mascot:dock { selector }, mascot:hide, mascot:show,
// and the landing's progress event (step >= 1 slides the stage away).
//
// Lifecycle rules (same as hero_scene_controller.js):
// - prefers-reduced-motion: never import Three; show the SVG twin statically.
// - any failure (no WebGL, import error, a frame throwing): warn, tear down, SVG twin.
// - resize debounced through rAF; clock paused when hidden, away or offscreen.
// - palette follows html[data-theme] through a MutationObserver.
// - disconnect() removes every listener and timer and disposes every GPU
//   resource; safe to call twice.

const STAGE = { desktop: [260, 320], phone: [170, 210] }
const ENTRANCE_MS = 1600
const DOCK_MS = 700
const SAFETY_MS = 500
const CAMERA_POS = [0, 2.3, 7.3]
const CAMERA_LOOK = [0, 1.75, 0]
const HEMI_INTENSITY = 1.1
const SUN_INTENSITY = 1.8

export default class extends Controller {
  static targets = ["canvas", "bubble", "fallback"]
  static values = {
    mode: { type: String, default: "landing" },
    dockSelector: { type: String, default: "" },
    entranceDelay: { type: Number, default: 700 },
    progressEvent: { type: String, default: "landing:progress" }
  }
  // The view passes its own BEM classes (data-mascot-arrived-class="mascot--arrived" ...).
  static classes = ["offstage", "onstage", "arrived", "docked", "away", "hidden", "static", "fallback", "bubbleVisible"]

  connect() {
    this._connected = true
    this._sceneDown = false
    this.arrived = false
    this.docked = false
    this.away = false
    this.hiddenByEvent = false
    this.paused = false
    this.phase = null
    this.timers = new Set()
    this.pointer = null
    this._evaluateDevice()
    this._bindWindowEvents()

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.showFallback("reduced-motion")
      return
    }
    this._currentTheme = this._readTheme()
    this.initScene()
  }

  get landing() { return this.modeValue !== "docked" }

  _readTheme() {
    return document.documentElement.dataset.theme === "light" ? "light" : "dark"
  }

  _evaluateDevice() {
    const coarse = window.matchMedia("(pointer: coarse)").matches
    this.isMobile = coarse || window.innerWidth < 768
  }

  _bindWindowEvents() {
    this.speakHandler = (event) => this.onSpeak(event)
    this.dockHandler = (event) => this.onDock(event)
    this.hideHandler = () => this.onHide()
    this.showHandler = () => this.onShow()
    window.addEventListener("mascot:speak", this.speakHandler)
    window.addEventListener("mascot:dock", this.dockHandler)
    window.addEventListener("mascot:hide", this.hideHandler)
    window.addEventListener("mascot:show", this.showHandler)
    this.resizeHandler = () => this.onResize()
    window.addEventListener("resize", this.resizeHandler)
    window.addEventListener("orientationchange", this.resizeHandler)
    this.transitionHandler = (event) => this.onTransitionEnd(event)
    this.element.addEventListener("transitionend", this.transitionHandler)
    if (this.landing) {
      this.progressHandler = (event) => this.onProgress(event)
      window.addEventListener(this.progressEventValue, this.progressHandler)
      window.dispatchEvent(new CustomEvent("landing:sync"))
    }
  }

  // ── Scene ─────────────────────────────────────────────────────────────

  async initScene() {
    try {
      const THREE = await import("three")
      if (!this._connected) return
      const [{ buildCharacter }, { Animator, talkDuration }, { paletteFor }] = await Promise.all([
        import("mascot/character"), import("mascot/animator"), import("mascot/palette")
      ])
      if (!this._connected) return
      if (!this.hasCanvasTarget) { this.showFallback("no-canvas"); return }

      this.THREE = THREE
      this.paletteFor = paletteFor
      this.talkDuration = talkDuration
      this.palette = paletteFor(this._currentTheme)
      this._tmpVec = new THREE.Vector3()

      this.renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true, powerPreference: "low-power" })
      this.renderer.setPixelRatio(this._chooseRendererPixelRatio())
      this.renderer.domElement.style.width = "100%"
      this.renderer.domElement.style.height = "100%"
      this.canvasTarget.appendChild(this.renderer.domElement)

      this.scene = new THREE.Scene()
      const [w, h] = this._stageSize()
      this.camera = new THREE.PerspectiveCamera(34, w / h, 0.1, 50)
      this.camera.position.set(...CAMERA_POS)
      this.camera.lookAt(...CAMERA_LOOK)
      this.renderer.setSize(w, h, false)

      this.hemi = new THREE.HemisphereLight(this.palette.sky, this.palette.ground, HEMI_INTENSITY)
      this.sun = new THREE.DirectionalLight(this.palette.sun, SUN_INTENSITY)
      this.sun.position.set(-3, 6, 4)
      this.scene.add(this.hemi, this.sun)

      this.character = buildCharacter(THREE, this.palette)
      this.scene.add(this.character.group)
      this.animator = new Animator(this.character.parts)

      this.clock = new THREE.Clock()
      this.animate()

      this.visibilityHandler = () => this.onVisibilityChange()
      document.addEventListener("visibilitychange", this.visibilityHandler)
      this.themeObserver = new MutationObserver(() => this.onThemeChange())
      this.themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] })
      if (!this.isMobile) this._bindPointer()

      this.emit("ready")
      if (this.landing) {
        this.animator.setState("offstage")
        this.entranceTimer = this._after(this.entranceDelayValue, () => this.startEntrance())
      } else {
        this.animator.setState("idle")
        this._swapClass(this.hasOffstageClass ? this.offstageClass : null, this.hasOnstageClass ? this.onstageClass : null)
        this.arrive()
      }
    } catch (e) {
      console.warn("Mascot scene init failed:", e)
      this.teardownScene()
      this.showFallback("error")
    }
  }

  _stageSize() {
    const w = this.hasCanvasTarget ? this.canvasTarget.clientWidth : 0
    const h = this.hasCanvasTarget ? this.canvasTarget.clientHeight : 0
    if (w > 0 && h > 0) return [w, h]
    return this.isMobile ? STAGE.phone : STAGE.desktop
  }

  _chooseRendererPixelRatio() {
    const dpr = window.devicePixelRatio || 1
    return Math.min(dpr, this.isMobile ? 1.5 : 2)
  }

  _bindPointer() {
    if (this.pointerHandler) return
    this.pointerHandler = (event) => this.onPointerMove(event)
    window.addEventListener("mousemove", this.pointerHandler, { passive: true })
  }

  _unbindPointer() {
    if (!this.pointerHandler) return
    window.removeEventListener("mousemove", this.pointerHandler)
    this.pointerHandler = null
    this.pointer = null
    if (this.animator) this.animator.setPointer(null)
  }

  // ── Animation loop ────────────────────────────────────────────────────

  animate() {
    if (!this._connected || this._sceneDown) return
    this.animationId = requestAnimationFrame(() => this.animate())
    if (this.paused || !this.renderer) return
    try {
      const dt = Math.min(0.05, this.clock.getDelta())
      this.animator.update(dt)
      this.renderer.render(this.scene, this.camera)
    } catch (e) {
      console.warn("Mascot scene stopped:", e)
      this.teardownScene()
      this.showFallback("error")
    }
  }

  _updatePaused() {
    this.paused = document.hidden || this.away || this.hiddenByEvent
    if (!this.clock) return
    if (this.paused) this.clock.stop()
    else if (!this.clock.running) this.clock.start()
  }

  // ── Entrance and arrival ──────────────────────────────────────────────

  // The stage slides in through CSS (offstage -> onstage) while the character
  // gaits in place; transitionend (or the safety timer) calls arrive().
  startEntrance() {
    if (!this._connected || this.arrived) return
    if (this.animator) this.animator.enter()
    this.phase = "entering"
    void this.element.offsetWidth
    this._swapClass(this.hasOffstageClass ? this.offstageClass : null, this.hasOnstageClass ? this.onstageClass : null)
    this.safetyTimer = this._after(ENTRANCE_MS + SAFETY_MS, () => this.arrive())
  }

  arrive() {
    if (!this._connected || this.arrived) return
    this.arrived = true
    this.phase = null
    this._clear(this.safetyTimer)
    if (this.animator && this.landing) this.animator.arrive()
    if (this.hasArrivedClass) this.element.classList.add(this.arrivedClass)
    this.measureStage()
    this.positionBubble()
    if (this.landing) this.showBubble()
    this.emit("arrived")
  }

  onTransitionEnd(event) {
    if (event.target !== this.element || event.propertyName !== "transform") return
    if (this.phase === "entering") this.arrive()
    else if (this.phase === "docking") this.finishDock()
  }

  // ── Bubble ────────────────────────────────────────────────────────────

  // Projects the head anchor into the stage box; the CSS reads the two custom
  // properties (and falls back to fixed percentages on the SVG path).
  positionBubble() {
    if (!this.character || !this.camera) return
    const [w, h] = this._stageSize()
    this.character.anchor.updateWorldMatrix(true, false)
    const v = this._tmpVec.setFromMatrixPosition(this.character.anchor.matrixWorld).project(this.camera)
    this.element.style.setProperty("--mascot-bubble-x", `${(((v.x + 1) / 2) * w).toFixed(1)}px`)
    this.element.style.setProperty("--mascot-bubble-y", `${(((1 - v.y) / 2) * h).toFixed(1)}px`)
  }

  showBubble() {
    if (!this.hasBubbleTarget || this.docked) return
    this.bubbleTarget.hidden = false
    if (this.hasBubbleVisibleClass) this.bubbleTarget.classList.add(this.bubbleVisibleClass)
  }

  hideBubble() {
    if (!this.hasBubbleTarget) return
    if (this.hasBubbleVisibleClass) this.bubbleTarget.classList.remove(this.bubbleVisibleClass)
    this.bubbleTarget.hidden = true
  }

  letsGo() {
    this.hideBubble()
    this.emit("lets-go")
  }

  dismiss() {
    this.hideBubble()
  }

  // ── Speak, dock, hide, show ───────────────────────────────────────────

  onSpeak(event) {
    if (!this.animator) return
    const chars = event.detail && event.detail.chars
    this.animator.speak(this.talkDuration(chars))
  }

  // FLIP toward the slot: translate and scale only, from the stage's resting
  // box (offset* ignores transforms) to the target's rect.
  onDock(event) {
    const selector = (event.detail && event.detail.selector) || this.dockSelectorValue
    if (!selector || this.docked) return
    const target = document.querySelector(selector)
    if (!target) return
    this.dockTarget = target
    this.docked = true
    this.hideBubble()
    this.applyDock()
    if (this.animator) this.animator.startDock()
    this.phase = "docking"
    if (this.hasAwayClass) this.element.classList.remove(this.awayClass)
    this.away = false
    if (this.hasDockedClass) this.element.classList.add(this.dockedClass)
    if (this.isMobile && this.hasHiddenClass) this.element.classList.add(this.hiddenClass)
    this._updatePaused()
    this.safetyTimer = this._after(DOCK_MS + SAFETY_MS, () => this.finishDock())
  }

  applyDock() {
    if (!this.dockTarget || !this.dockTarget.isConnected) return
    const rect = this.dockTarget.getBoundingClientRect()
    const rest = this.restingRect()
    if (!rect.width || !rect.height || !rest.width || !rest.height) return
    const scale = Math.min(1, rect.height / rest.height, (rect.width * 1.6) / rest.width)
    const dx = rect.left + rect.width / 2 - (rest.left + rest.width / 2)
    const dy = rect.top + rect.height / 2 - (rest.top + rest.height / 2)
    this.element.style.setProperty("--mascot-dock-x", `${dx.toFixed(1)}px`)
    this.element.style.setProperty("--mascot-dock-y", `${dy.toFixed(1)}px`)
    this.element.style.setProperty("--mascot-dock-scale", scale.toFixed(3))
  }

  measureStage() {
    const rest = this.restingRect()
    this.stageCenter = { x: rest.left + rest.width / 2, y: rest.top + rest.height / 2 }
  }

  restingRect() {
    const el = this.element
    return { left: el.offsetLeft, top: el.offsetTop, width: el.offsetWidth, height: el.offsetHeight }
  }

  // handoff "svg": the stage has hidden itself (phones, or no WebGL to keep),
  // so the panel shows its own avatar. "canvas": the live stage stays docked.
  finishDock() {
    if (!this._connected || this.phase !== "docking") return
    this.phase = null
    this._clear(this.safetyTimer)
    if (this.isMobile || !this.renderer) {
      this.hiddenByEvent = true
      if (this.hasHiddenClass) this.element.classList.add(this.hiddenClass)
      this.teardownScene()
      this.emit("docked", { handoff: "svg" })
    } else {
      this.positionBubble()
      this.emit("docked", { handoff: "canvas" })
    }
  }

  onHide() {
    this.hiddenByEvent = true
    if (this.hasHiddenClass) this.element.classList.add(this.hiddenClass)
    this.hideBubble()
    this._updatePaused()
  }

  onShow() {
    this.hiddenByEvent = false
    if (this.hasHiddenClass) this.element.classList.remove(this.hiddenClass)
    this._updatePaused()
  }

  // The tour: step >= 1 slides the stage away, step 0 brings it back.
  onProgress(event) {
    if (this.docked) return
    const step = event.detail ? Number(event.detail.step) || 0 : 0
    const away = step >= 1
    if (away === this.away) return
    this.away = away
    if (this.hasAwayClass) this.element.classList.toggle(this.awayClass, away)
    this._updatePaused()
  }

  // ── Environment ───────────────────────────────────────────────────────

  onPointerMove(event) {
    if (!this.stageCenter || !this.animator) return
    const x = (event.clientX - this.stageCenter.x) / (window.innerWidth / 2)
    const y = -(event.clientY - this.stageCenter.y) / (window.innerHeight / 2)
    this.pointer = { x, y }
    this.animator.setPointer(this.pointer)
  }

  onResize() {
    if (this._resizeRaf) cancelAnimationFrame(this._resizeRaf)
    this._resizeRaf = requestAnimationFrame(() => this._handleResize())
  }

  _handleResize() {
    this._resizeRaf = null
    if (!this._connected) return
    const wasMobile = this.isMobile
    this._evaluateDevice()
    if (this.renderer && this.camera) {
      const [w, h] = this._stageSize()
      this.camera.aspect = w / h
      this.camera.updateProjectionMatrix()
      this.renderer.setPixelRatio(this._chooseRendererPixelRatio())
      this.renderer.setSize(w, h, false)
      if (wasMobile && !this.isMobile) this._bindPointer()
      else if (!wasMobile && this.isMobile) this._unbindPointer()
    }
    this.measureStage()
    if (this.docked) this.applyDock()
    this.positionBubble()
  }

  onVisibilityChange() { this._updatePaused() }

  onThemeChange() {
    const next = this._readTheme()
    if (next === this._currentTheme) return
    this._currentTheme = next
    if (!this.character || !this.paletteFor) return
    this.palette = this.paletteFor(next)
    this.character.applyPalette(this.palette)
    this.hemi.color.setHex(this.palette.sky)
    this.hemi.groundColor.setHex(this.palette.ground)
    this.sun.color.setHex(this.palette.sun)
  }

  // ── Fallback ──────────────────────────────────────────────────────────

  // The SVG twin stands in for the scene (reduced motion, no WebGL, a crash):
  // placed onstage at once, bubble shown, arrived dispatched.
  showFallback(reason) {
    if (this._fallbackShown) return
    this._fallbackShown = true
    if (this.animator) this.animator.setStatic()
    if (this.hasFallbackClass) this.element.classList.add(this.fallbackClass)
    if (this.hasStaticClass) this.element.classList.add(this.staticClass)
    if (this.hasCanvasTarget) this.canvasTarget.hidden = true
    if (this.hasFallbackTarget) this.fallbackTarget.hidden = false
    this._swapClass(this.hasOffstageClass ? this.offstageClass : null, this.hasOnstageClass ? this.onstageClass : null)
    this.emit("fallback", { reason })
    if (this.phase === "docking") this.finishDock()
    this.arrive()
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  emit(name, detail = {}) {
    window.dispatchEvent(new CustomEvent(`mascot:${name}`, { detail }))
  }

  _swapClass(remove, add) {
    if (remove) this.element.classList.remove(remove)
    if (add) this.element.classList.add(add)
  }

  _after(ms, fn) {
    const id = setTimeout(() => { this.timers.delete(id); fn() }, ms)
    this.timers.add(id)
    return id
  }

  _clear(id) {
    if (id === undefined || id === null) return
    clearTimeout(id)
    this.timers.delete(id)
  }

  // ── Cleanup ───────────────────────────────────────────────────────────

  // Stops rendering and frees every GPU resource; safe to call more than once.
  teardownScene() {
    this._sceneDown = true
    if (this.animationId) { cancelAnimationFrame(this.animationId); this.animationId = null }
    if (this.character) this.character.dispose()
    if (this.renderer) {
      this.renderer.dispose()
      const element = this.renderer.domElement
      if (element && element.parentNode) element.parentNode.removeChild(element)
    }
    this.character = null
    this.animator = null
    this.scene = null
    this.camera = null
    this.renderer = null
    this.hemi = null
    this.sun = null
    this.clock = null
  }

  disconnect() {
    this._connected = false
    this.timers.forEach((id) => clearTimeout(id))
    this.timers.clear()
    if (this._resizeRaf) { cancelAnimationFrame(this._resizeRaf); this._resizeRaf = null }
    window.removeEventListener("mascot:speak", this.speakHandler)
    window.removeEventListener("mascot:dock", this.dockHandler)
    window.removeEventListener("mascot:hide", this.hideHandler)
    window.removeEventListener("mascot:show", this.showHandler)
    window.removeEventListener("resize", this.resizeHandler)
    window.removeEventListener("orientationchange", this.resizeHandler)
    this.element.removeEventListener("transitionend", this.transitionHandler)
    if (this.progressHandler) window.removeEventListener(this.progressEventValue, this.progressHandler)
    if (this.visibilityHandler) document.removeEventListener("visibilitychange", this.visibilityHandler)
    if (this.themeObserver) { this.themeObserver.disconnect(); this.themeObserver = null }
    this._unbindPointer()
    this.teardownScene()
    this.THREE = null
  }
}
