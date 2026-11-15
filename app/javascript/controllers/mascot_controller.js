import { Controller } from "@hotwired/stimulus"
import { reducedMotion } from "preferences/motion"

// Aluni, the seedling mascot: a small Three.js stage (vendored r169, loaded
// lazily next to the mascot/* modules) with an HTML speech bubble. Three modes:
//
//   preloader  the landing. The stage is the page's loading indicator: it
//              starts centred and enlarged (a transform of its corner box, so
//              the corner stays the resting box), shows the SVG twin at once
//              and swaps in the character the moment the renderer is ready,
//              which sprouts from the soil and idles. On the go signal the
//              stage moves to its corner (0.9 s), waves, shows the bubble and
//              later docks (FLIP) into the finder's slot.
//   landing    the earlier walk-in: fixed bottom-left, starts offstage, slides
//              in while the character gaits in place, waves, shows the bubble.
//   docked     the companion on /app/onboarding: relative in its container, no
//              entrance, idle from the start, no bubble.
//
// The go signal in preloader mode: window "welcome:done" when a #welcome
// element exists at connect (the first-visit overlay; the stage sits above
// it), otherwise preloader:ready, derived here: window "hero:revealed" has
// fired, at least 0.9 s have passed since connect and the sprout has finished,
// or 2.5 s have passed. The centre is the viewport's, or #welcome-stage's box
// when the overlay has one.
//
// Events on window. Dispatched: mascot:ready, mascot:arrived, mascot:docked
// { handoff: "canvas" | "svg" }, mascot:fallback, mascot:lets-go. Listened:
// mascot:speak { chars }, mascot:dock { selector }, mascot:hide, mascot:show,
// welcome:done, hero:revealed, and the landing's progress event (step >= 1
// slides the stage away).
//
// Lifecycle rules (same as hero_scene_controller.js):
// - reduced motion (the preference or the media query): never import Three;
//   show the SVG twin statically, in the corner at once.
// - any failure (no WebGL, import error, a frame throwing): warn, tear down, SVG twin.
// - resize debounced through rAF; clock paused when hidden, away or offscreen.
// - palette follows html[data-theme] through a MutationObserver.
// - disconnect() removes every listener and timer and disposes every GPU
//   resource; safe to call twice.

const STAGE = { desktop: [260, 320], phone: [170, 210] }
const ENTRANCE_MS = 1600
const LEAVE_MS = 900
const DOCK_MS = 700
const SAFETY_MS = 500
const CENTER_MIN_MS = 1200
const CENTER_FALLBACK_MS = 4500
const CENTER_SCALE_MIN = 1.2
const CENTER_SCALE_MAX = 2.2
const CENTER_PIXEL_RATIO_MAX = 3
const WELCOME_ID = "welcome"
const CENTER_ANCHOR_ID = "welcome-stage"
// From a little above, as the hero looks at the fields, so the leaf tops show.
const CAMERA_POS = [0, 3.5, 6.7]
const CAMERA_LOOK = [0, 1.55, 0]
// A soft hemisphere fill, the key light from the upper left and a low gold rim
// light from behind on the right, so leaf edges catch the accent.
const LIGHTS = { hemi: 1.0, key: 2.2, rim: 0.7 }
const KEY_POS = [-3, 6, 4]
const RIM_POS = [3, 3.5, -4]
const COMPANION_QUERY = "(min-width: 1025px)"
const BUBBLE_ATTEND = { x: 0.6, y: 0.7 }
const DOCK_ATTEND_SELECTOR = ".panel__body"

const clamp = (value, min, max) => Math.min(max, Math.max(min, value))

export default class extends Controller {
  static targets = ["canvas", "bubble", "fallback"]
  static values = {
    mode: { type: String, default: "landing" },
    dockSelector: { type: String, default: "" },
    entranceDelay: { type: Number, default: 700 },
    progressEvent: { type: String, default: "landing:progress" },
    // Growth stage 0..3 at connect (the companion renders the profile's); the
    // window event mascot:stage { stage } moves it later.
    stage: { type: Number, default: 0 },
    rootsSelector: { type: String, default: "#mascot-roots" }
  }
  // The view passes its own BEM classes (data-mascot-arrived-class="mascot--arrived" ...).
  static classes = ["offstage", "onstage", "centered", "leaving", "arrived", "docked", "away", "hidden", "static", "fallback", "bubbleVisible"]

  connect() {
    this._connected = true
    this._sceneDown = false
    this.arrived = false
    this.docked = false
    this.away = false
    this.hiddenByEvent = false
    this.paused = false
    this.phase = null
    this.centered = false
    this.centerScale = 1
    this.waitingForWelcome = false
    this.heroRevealed = false
    this.minElapsed = false
    this.sprouting = false
    this.timers = new Set()
    this.pointer = null
    this.stage = clamp(Number(this.stageValue) || 0, 0, 3)
    this.element.dataset.stage = String(this.stage)
    this._evaluateDevice()
    this._bindWindowEvents()

    if (reducedMotion()) {
      this.showFallback("reduced-motion")
      return
    }
    this._currentTheme = this._readTheme()
    if (this.preloader) this.startPreloader()
    // The companion is display: none below 1025 px: no scene until it shows.
    if (!this.landing && this.element.getClientRects().length === 0) {
      this.companionQuery = window.matchMedia(COMPANION_QUERY)
      this.companionHandler = () => {
        if (!this._connected || this.renderer || this._fallbackShown) return
        if (this.element.getClientRects().length === 0) return
        this.companionQuery.removeEventListener("change", this.companionHandler)
        this.companionHandler = null
        this.initScene()
      }
      this.companionQuery.addEventListener("change", this.companionHandler)
      return
    }
    this.initScene()
  }

  get preloader() { return this.modeValue === "preloader" }
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
    this.stageHandler = (event) => this.onStage(event)
    this.attendHandler = (event) => this.onAttend(event)
    window.addEventListener("mascot:stage", this.stageHandler)
    window.addEventListener("mascot:attend", this.attendHandler)
    this.motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.motionHandler = () => this.onMotionChange()
    this.motionQuery.addEventListener("change", this.motionHandler)
    this.resizeHandler = () => this.onResize()
    window.addEventListener("resize", this.resizeHandler)
    window.addEventListener("orientationchange", this.resizeHandler)
    this.transitionHandler = (event) => this.onTransitionEnd(event)
    this.element.addEventListener("transitionend", this.transitionHandler)
    if (this.preloader) {
      this.welcomeDoneHandler = () => this.leaveCenter()
      this.heroRevealedHandler = () => { this.heroRevealed = true; this._checkReady() }
      window.addEventListener("welcome:done", this.welcomeDoneHandler)
      window.addEventListener("hero:revealed", this.heroRevealedHandler)
    }
    if (this.landing) {
      this.progressHandler = (event) => this.onProgress(event)
      window.addEventListener(this.progressEventValue, this.progressHandler)
      window.dispatchEvent(new CustomEvent("landing:sync"))
    }
  }

  // ── Preloader ─────────────────────────────────────────────────────────

  // The view's class and the CSS defaults already centre the stage at first
  // paint; measure the exact centre, show the twin as the loading indicator
  // and start the gate (unless the welcome overlay owns the go signal).
  startPreloader() {
    this.centered = this.hasCenteredClass && this.element.classList.contains(this.centeredClass)
    this.waitingForWelcome = document.getElementById(WELCOME_ID) !== null
    this.applyCenter()
    if (this.hasFallbackTarget) this.fallbackTarget.hidden = false
    if (this.waitingForWelcome) return
    this.minTimer = this._after(CENTER_MIN_MS, () => { this.minElapsed = true; this._checkReady() })
    this.readyTimer = this._after(CENTER_FALLBACK_MS, () => this.leaveCenter())
  }

  // The centred transform: the resting (corner) box translated to the anchor's
  // centre (#welcome-stage when the overlay has one, else the viewport) and
  // scaled up; the same maths as applyDock, so the corner stays the resting box.
  applyCenter() {
    if (!this.centered) return
    const rest = this.restingRect()
    if (!rest.width || !rest.height) return
    const vw = window.innerWidth
    const vh = window.innerHeight
    const anchor = document.getElementById(CENTER_ANCHOR_ID)
    const box = anchor ? anchor.getBoundingClientRect() : null
    let cx = vw / 2
    let cy = vh / 2
    let scale = (0.5 * Math.min(vw, vh)) / rest.height
    let min = CENTER_SCALE_MIN
    if (box && box.width > 0 && box.height > 0) {
      cx = box.left + box.width / 2
      cy = box.top + box.height / 2
      scale = Math.min(scale, box.height / rest.height, box.width / rest.width)
      min = 1
    }
    this.centerScale = clamp(scale, min, CENTER_SCALE_MAX)
    const dx = cx - (rest.left + rest.width / 2)
    const dy = cy - (rest.top + rest.height / 2)
    this.element.style.setProperty("--mascot-pre-x", `${dx.toFixed(1)}px`)
    this.element.style.setProperty("--mascot-pre-y", `${dy.toFixed(1)}px`)
    this.element.style.setProperty("--mascot-pre-scale", this.centerScale.toFixed(3))
  }

  // preloader:ready, derived: the hero copy is revealed, the centred phase has
  // lasted its minimum and the sprout has finished (the fallback timer calls
  // leaveCenter() directly).
  _checkReady() {
    if (this.waitingForWelcome || this.arrived || this.phase === "leaving") return
    if (this.heroRevealed && this.minElapsed && !this.sprouting) this.leaveCenter()
  }

  startSprout() {
    this.sprouting = true
    this.sproutTimer = this._after(this.animator.sprout(), () => { this.sprouting = false; this._checkReady() })
  }

  // The go signal: the stage moves from the centre to its resting corner (the
  // CSS transition once the centred class goes), then transitionend or the
  // safety timer calls arrive(). Runs at most once.
  leaveCenter() {
    if (!this._connected || this.arrived || this.phase === "leaving") return
    this._clear(this.minTimer)
    this._clear(this.readyTimer)
    if (!this.centered) { this.arrive(); return }
    this.phase = "leaving"
    this.centered = false
    if (this.hasLeavingClass) this.element.classList.add(this.leavingClass)
    void this.element.offsetWidth
    this.element.classList.remove(this.centeredClass)
    this.safetyTimer = this._after(LEAVE_MS + SAFETY_MS, () => this.arrive())
  }

  // Leaves the centred state without the move (the stage docks from the
  // centre, or the twin takes over): classes and timers only.
  _dropCenter() {
    this.centered = false
    this._clear(this.minTimer)
    this._clear(this.readyTimer)
    if (this.hasCenteredClass) this.element.classList.remove(this.centeredClass)
    if (this.hasLeavingClass) this.element.classList.remove(this.leavingClass)
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
      this.renderer.toneMapping = THREE.ACESFilmicToneMapping
      this.renderer.toneMappingExposure = this.palette.exposure
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

      this.hemi = new THREE.HemisphereLight(this.palette.sky, this.palette.ground, LIGHTS.hemi)
      this.sun = new THREE.DirectionalLight(this.palette.sun, LIGHTS.key)
      this.sun.position.set(...KEY_POS)
      this.rim = new THREE.DirectionalLight(this.palette.rim, LIGHTS.rim)
      this.rim.position.set(...RIM_POS)
      this.scene.add(this.hemi, this.sun, this.rim)

      this.character = buildCharacter(THREE, this.palette)
      this.scene.add(this.character.group)
      this.animator = new Animator(this.character.parts)
      this.animator.setStage(this.stage, { immediate: true })
      // The first frame renders in this state: the closed seed about to sprout
      // for the preloader (unless the go signal already came), offstage for
      // the walk-in, idle at its stage for the companion.
      if (this.preloader) {
        if (this.arrived) this.animator.setState("idle")
        else this.startSprout()
      } else {
        this.animator.setState(this.landing ? "offstage" : "idle")
      }

      this.clock = new THREE.Clock()
      this.animate()

      this.visibilityHandler = () => this.onVisibilityChange()
      document.addEventListener("visibilitychange", this.visibilityHandler)
      this.themeObserver = new MutationObserver(() => { this.onThemeChange(); this.onMotionChange() })
      this.themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme", "data-motion"] })
      if (!this.isMobile) this._bindPointer()

      this.emit("ready")
      if (this.preloader) {
        // The character has its first frame: the twin steps aside.
        if (this.hasFallbackTarget) this.fallbackTarget.hidden = true
        if (this.arrived) this.positionBubble()
      } else if (this.landing) {
        this.entranceTimer = this._after(this.entranceDelayValue, () => this.startEntrance())
      } else {
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

  // The centred stage is CSS-scaled up, so it renders at the scaled
  // resolution (capped) to stay crisp; arrive() drops back to the base ratio.
  _chooseRendererPixelRatio() {
    const dpr = window.devicePixelRatio || 1
    const base = Math.min(dpr, this.isMobile ? 1.5 : 2)
    return this.centered ? Math.min(base * this.centerScale, CENTER_PIXEL_RATIO_MAX) : base
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

  // The stage is in its resting corner: wave, bubble, mascot:arrived. Reached
  // from the walk-in, from the preloader's move and from the twin.
  arrive() {
    if (!this._connected || this.arrived) return
    this.arrived = true
    this.phase = null
    this._clear(this.safetyTimer)
    this._dropCenter()
    if (this.renderer) this.renderer.setPixelRatio(this._chooseRendererPixelRatio())
    if (this.animator && this.landing) this.animator.arrive()
    if (this.hasArrivedClass) this.element.classList.add(this.arrivedClass)
    this.measureStage()
    this.positionBubble()
    if (this.landing) this.showBubble()
    this.emit("arrived")
  }

  onTransitionEnd(event) {
    if (event.target !== this.element || event.propertyName !== "transform") return
    if (this.phase === "entering" || this.phase === "leaving") this.arrive()
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
    if (this.animator) this.animator.attend(BUBBLE_ATTEND)
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

  // Growth stage 0..3 (mascot:stage { stage }): eased by the animator, mirrored
  // on the element as data-stage so the page and the specs can read it.
  onStage(event) {
    const next = clamp(Number(event.detail && event.detail.stage) || 0, 0, 3)
    this.stage = next
    this.element.dataset.stage = String(next)
    if (this.animator) this.animator.setStage(next)
  }

  // Lean toward something (mascot:attend): { x, y } in viewport pixels,
  // { selector } for an element's centre, or { clear: true }.
  onAttend(event) {
    if (!this.animator) return
    const detail = event.detail || {}
    if (detail.clear) { this.animator.attend(null); return }
    let x = Number(detail.x)
    let y = Number(detail.y)
    if (detail.selector) {
      const target = document.querySelector(detail.selector)
      if (!target) return
      const rect = target.getBoundingClientRect()
      x = rect.left + rect.width / 2
      y = rect.top + rect.height / 2
    }
    if (!Number.isFinite(x) || !Number.isFinite(y)) return
    this.animator.attend(this._toStageUnits(x, y))
  }

  // Viewport pixels to the -1..1 units the animator uses (the pointer's convention).
  _toStageUnits(clientX, clientY) {
    if (!this.stageCenter) this.measureStage()
    return {
      x: (clientX - this.stageCenter.x) / (window.innerWidth / 2),
      y: -(clientY - this.stageCenter.y) / (window.innerHeight / 2)
    }
  }

  // The motion preference flipped while the scene is up (the intro bubble's
  // "Less motion", or the system): the plant stands still but stays.
  onMotionChange() {
    if (!this.animator) return
    this.animator.setMotion(reducedMotion())
  }

  // FLIP toward the slot: translate and scale only, from the stage's resting
  // box (offset* ignores transforms) to the target's rect. Asked for while
  // still centred or moving (the hero's button during the preloader), the FLIP
  // starts from where the stage is and the corner, the wave and the bubble
  // are skipped.
  onDock(event) {
    const selector = (event.detail && event.detail.selector) || this.dockSelectorValue
    if (!selector || this.docked) return
    const target = document.querySelector(selector)
    if (!target) return
    this.dockTarget = target
    this.docked = true
    if (this.centered || this.phase === "leaving") {
      this._dropCenter()
      this._clear(this.safetyTimer)
      this.arrived = true
    }
    this.hideBubble()
    this.applyDock()
    if (this.animator) {
      this.animator.setDockDirection(parseFloat(this.element.style.getPropertyValue("--mascot-dock-x")) || 1)
      this.animator.startDock()
    }
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
      this.measureStage()
      const body = this.dockTarget && this.dockTarget.closest(".panel")
      const focus = body && body.querySelector(DOCK_ATTEND_SELECTOR)
      if (focus && this.animator) {
        const rect = focus.getBoundingClientRect()
        this.animator.attend(this._toStageUnits(rect.left + rect.width / 2, rect.top + rect.height / 2))
      }
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
    if (this.centered) this.applyCenter()
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
    this.rim.color.setHex(this.palette.rim)
    if (this.renderer) this.renderer.toneMappingExposure = this.palette.exposure
  }

  // ── Fallback ──────────────────────────────────────────────────────────

  // The SVG twin stands in for the scene (reduced motion, no WebGL, a crash):
  // placed in the corner at once (no centred phase, no transition), bubble
  // shown, arrived dispatched.
  showFallback(reason) {
    if (this._fallbackShown) return
    this._fallbackShown = true
    this._clear(this.sproutTimer)
    this.sprouting = false
    if (this.animator) this.animator.setStatic()
    if (this.hasFallbackClass) this.element.classList.add(this.fallbackClass)
    if (this.hasStaticClass) this.element.classList.add(this.staticClass)
    this._dropCenter()
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
    this.rim = null
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
    window.removeEventListener("mascot:stage", this.stageHandler)
    window.removeEventListener("mascot:attend", this.attendHandler)
    if (this.motionQuery) { this.motionQuery.removeEventListener("change", this.motionHandler); this.motionQuery = null }
    if (this.companionQuery && this.companionHandler) { this.companionQuery.removeEventListener("change", this.companionHandler); this.companionHandler = null }
    window.removeEventListener("resize", this.resizeHandler)
    window.removeEventListener("orientationchange", this.resizeHandler)
    this.element.removeEventListener("transitionend", this.transitionHandler)
    if (this.welcomeDoneHandler) window.removeEventListener("welcome:done", this.welcomeDoneHandler)
    if (this.heroRevealedHandler) window.removeEventListener("hero:revealed", this.heroRevealedHandler)
    if (this.progressHandler) window.removeEventListener(this.progressEventValue, this.progressHandler)
    if (this.visibilityHandler) document.removeEventListener("visibilitychange", this.visibilityHandler)
    if (this.themeObserver) { this.themeObserver.disconnect(); this.themeObserver = null }
    this._unbindPointer()
    this.teardownScene()
    this.THREE = null
  }
}
