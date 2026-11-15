import { Controller } from "@hotwired/stimulus"

// The main menu dial. The rotor turns under a finger or a mouse drag (with
// momentum and a spring that snaps to the nearest section), the mouse wheel,
// a trackpad or the arrow keys. The section under the top marker is the
// selection: the hub in the centre shows its copy while the wheel moves.
// Tapping the hub (or the selected wedge, or Enter) opens the section: a
// circle blooms from the hub to cover the screen and the section's panel
// rises on top, inside a modal <dialog>, so focus and Escape come for free.
//
// Angles are degrees. Section i sits at i * step in the rotor's frame, so it
// is under the marker when angle = -i * step. Panels follow sector order.

const SPRING = { stiffness: 190, damping: 23 }   // per second, a hint of overshoot
const DRAG_THRESHOLD = 6                          // px before a press becomes a drag
const WHEEL_STEP = 60                             // px of wheel delta per section
const MOMENTUM = 0.18                             // seconds of flick carried forward
const MAX_SPEED = 1400                            // deg/s
const EASE = "cubic-bezier(0.2, 0.8, 0.2, 1)"
const EASE_IN_OUT = "cubic-bezier(0.7, 0, 0.2, 1)"

const mod = (n, m) => ((n % m) + m) % m
const wrap = (deg) => mod(deg + 180, 360) - 180
const clamp = (n, limit) => Math.min(Math.max(n, -limit), limit)
const rise = (from) => [{ opacity: 0, transform: from }, { opacity: 1, transform: "none" }]

export default class extends Controller {
  static targets = ["wheel", "dial", "rotor", "sector", "label", "hub", "kicker", "title", "description",
                    "stage", "dialog", "bloom", "panelBar", "panel", "item"]
  static classes = ["selected", "dragging"]

  connect() {
    this.count = this.sectorTargets.length
    this.step = 360 / this.count
    this.angle = this.target = this.velocity = this.wheelDelta = 0
    this.index = -1
    this.animations = []
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    // Also resets a page restored from Turbo's cache mid-turn or mid-panel.
    if (this.dialogTarget.open) this.dialogTarget.close()
    this.render()
    this.sync(false)
    // A small turn after the entrance shows the wheel moves.
    if (!this.reduced) this.nudgeTimer = setTimeout(() => this.settleTo(0, -170), 1300)
  }

  disconnect() {
    cancelAnimationFrame(this.frame)
    clearTimeout(this.nudgeTimer)
    clearTimeout(this.wheelTimer)
    this.cancelAnimations()
  }

  get isOpen() {
    return this.dialogTarget.open
  }

  // Pointer: a press becomes a drag past a few pixels, so taps still click.

  press(event) {
    if (event.button > 0 || this.isOpen) return
    this.interacted()
    this.stopMotion()
    const rect = this.wheelTarget.getBoundingClientRect()
    const centre = { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 }
    this.pointer = {
      id: event.pointerId, x: event.clientX, y: event.clientY, centre, deadZone: rect.width * 0.08,
      angle: this.angleAt(event, centre), time: event.timeStamp, dragging: false
    }
  }

  move(event) {
    const pointer = this.pointer
    if (pointer?.id !== event.pointerId) return

    if (!pointer.dragging) {
      if (Math.hypot(event.clientX - pointer.x, event.clientY - pointer.y) < DRAG_THRESHOLD) return
      pointer.dragging = true
      this.velocity = 0
      this.wheelTarget.setPointerCapture(pointer.id)
      this.element.classList.add(this.draggingClass)
    }

    const angle = this.angleAt(event, pointer.centre)
    const delta = wrap(angle - pointer.angle)
    const dt = Math.max(event.timeStamp - pointer.time, 1) / 1000
    pointer.angle = angle
    pointer.time = event.timeStamp

    // Near the centre the angle swings wildly; follow it without turning.
    const { x, y } = pointer.centre
    if (Math.hypot(event.clientX - x, event.clientY - y) < pointer.deadZone) return

    this.angle += delta
    this.velocity = 0.7 * clamp(delta / dt, MAX_SPEED) + 0.3 * this.velocity
    this.render()
    this.sync()
  }

  release(event) {
    const pointer = this.pointer
    if (pointer?.id !== event.pointerId) return
    this.pointer = null

    if (!pointer.dragging) {
      // A tap may have caught the wheel mid-turn: let it land on a section.
      this.settleTo(this.snap(this.angle))
      return
    }

    this.element.classList.remove(this.draggingClass)
    // The click that follows a drag is not a tap.
    this.suppressClick = true
    setTimeout(() => { this.suppressClick = false })

    const held = event.timeStamp - pointer.time > 90
    const velocity = held || event.type === "pointercancel" ? 0 : this.velocity
    this.settleTo(this.snap(this.angle + velocity * MOMENTUM), velocity)
  }

  // Wheel and trackpad: whole sections, a short queue at most.

  scroll(event) {
    if (this.isOpen) return
    event.preventDefault()
    this.interacted()

    const raw = Math.abs(event.deltaY) >= Math.abs(event.deltaX) ? event.deltaY : event.deltaX
    this.wheelDelta += raw * [1, 16, 400][event.deltaMode]
    clearTimeout(this.wheelTimer)
    this.wheelTimer = setTimeout(() => { this.wheelDelta = 0 }, 180)

    while (Math.abs(this.wheelDelta) >= WHEEL_STEP) {
      const direction = Math.sign(this.wheelDelta)
      this.wheelDelta -= direction * WHEEL_STEP
      this.shift(direction)
    }
  }

  key(event) {
    const steps = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }
    if (event.key in steps) this.shift(steps[event.key])
    else if (event.key === "Home") this.rotateTo(0)
    else if (event.key === "End") this.rotateTo(this.count - 1)
    else if (event.key === "Enter" || event.key === " ") this.open()
    else return
    event.preventDefault()
    this.interacted()
  }

  // Taps: a wedge turns to the top; the selected wedge or the hub opens.

  pick({ params: { index } }) {
    if (this.suppressClick || this.isOpen) return
    this.interacted()
    if (index === this.index && Math.abs(this.angle - this.target) < this.step / 2) this.open()
    else this.rotateTo(index)
  }

  activate() {
    if (this.suppressClick) return
    this.interacted()
    this.open()
  }

  openSection({ params: { tone } }) {
    const index = this.sectorTargets.findIndex((sector) => sector.dataset.tone === tone)
    if (index < 0) return
    this.interacted()
    this.rotateTo(index)
    this.open(index)
  }

  // Motion

  snap(angle) {
    return Math.round(angle / this.step) * this.step
  }

  shift(direction) {
    const next = this.snap(this.target) - direction * this.step
    if (Math.abs(next - this.angle) <= this.step * 2.5) this.settleTo(next, this.velocity)
  }

  rotateTo(index) {
    const base = -index * this.step
    this.settleTo(base + Math.round((this.angle - base) / 360) * 360, this.velocity)
  }

  settleTo(target, velocity = 0) {
    cancelAnimationFrame(this.frame)
    this.target = target
    this.velocity = this.reduced ? 0 : velocity
    if (this.reduced) this.angle = target

    let last = performance.now()
    const tick = (now) => {
      let dt = Math.min((now - last) / 1000, 0.05)
      last = now
      for (; dt > 0; dt -= 0.004) {
        const h = Math.min(dt, 0.004)
        this.velocity += (-SPRING.stiffness * (this.angle - target) - SPRING.damping * this.velocity) * h
        this.angle += this.velocity * h
      }
      const done = Math.abs(this.angle - target) < 0.02 && Math.abs(this.velocity) < 0.5
      if (done) { this.angle = target; this.velocity = 0 }
      this.render()
      this.sync()
      if (!done) this.frame = requestAnimationFrame(tick)
    }
    if (this.reduced) { this.render(); this.sync() } else this.frame = requestAnimationFrame(tick)
  }

  stopMotion() {
    cancelAnimationFrame(this.frame)
    this.target = this.angle
  }

  interacted() {
    clearTimeout(this.nudgeTimer)
  }

  // Drawing: SVG transform attributes, so CSS transforms stay free for the
  // entrance and the selected lift. Labels counter-rotate about their own
  // origin to stay upright.

  render() {
    this.rotorTarget.setAttribute("transform", `rotate(${this.angle.toFixed(2)})`)
    this.labelTargets.forEach((label, i) => {
      label.setAttribute("transform", `rotate(${(-(this.angle + i * this.step)).toFixed(2)})`)
    })
  }

  sync(animate = true) {
    const index = mod(Math.round(-this.angle / this.step), this.count)
    if (index === this.index) return

    const forward = mod(index - this.index, this.count) <= this.count / 2
    this.index = index
    const sector = this.sectorTargets[index]
    const { tone, kicker, title, description, openLabel } = sector.dataset

    this.sectorTargets.forEach((s) => s.classList.toggle(this.selectedClass, s === sector))
    this.element.dataset.tone = tone
    this.dialTarget.setAttribute("aria-valuenow", index + 1)
    this.dialTarget.setAttribute("aria-valuetext", title)
    this.hubTarget.setAttribute("aria-label", openLabel)

    const copy = [[this.kickerTarget, kicker], [this.titleTarget, title], [this.descriptionTarget, description]]
    copy.forEach(([el, text], i) => {
      el.textContent = text
      if (animate && !this.reduced) {
        el.animate(rise(`translateX(${forward ? 10 : -10}px)`), { duration: 280, delay: i * 35, easing: EASE, fill: "backwards" })
      }
    })

    if (this.pointer?.dragging) navigator.vibrate?.(5)
  }

  // Opening and closing

  open(index = this.index) {
    if (this.isOpen) return
    const sector = this.sectorTargets[index]
    const panel = this.panelTargets[index]
    this.panelTargets.forEach((p) => { p.hidden = p !== panel })
    this.activePanel = panel
    this.dialogTarget.dataset.tone = sector.dataset.tone
    this.dialogTarget.setAttribute("aria-labelledby", panel.getAttribute("aria-labelledby"))

    // The bloom starts as the hub and grows past the screen's diagonal.
    const hub = this.hubTarget.getBoundingClientRect()
    const stage = this.stageTarget.getBoundingClientRect()
    const radius = hub.width / 2
    const cx = hub.left + radius
    const cy = hub.top + radius
    this.bloomScale = (Math.hypot(window.innerWidth, window.innerHeight) / radius) * 1.05
    Object.assign(this.bloomTarget.style, {
      left: `${hub.left}px`, top: `${hub.top}px`, width: `${hub.width}px`, height: `${hub.width}px`
    })
    this.stageTarget.style.transformOrigin = `${cx - stage.left}px ${cy - stage.top}px`

    this.cancelAnimations()
    this.closing = false
    this.dialogTarget.showModal()
    this.dialogTarget.scrollTop = 0

    const k = this.reduced ? 0 : 1
    const items = this.itemTargets.filter((item) => panel.contains(item))
    this.animations = [
      this.bloomTarget.animate(
        [{ transform: "scale(1)", opacity: 0.6 }, { transform: `scale(${this.bloomScale})`, opacity: 1 }],
        { duration: 640 * k, easing: EASE_IN_OUT, fill: "forwards" }),
      this.stageTarget.animate(
        [{ transform: "none", opacity: 1 }, { transform: "scale(1.18)", opacity: 0 }],
        { duration: 520 * k, easing: EASE_IN_OUT, fill: "forwards" }),
      this.panelBarTarget.animate(rise("translateY(-8px)"), { duration: 360 * k, delay: 360 * k, easing: EASE, fill: "both" }),
      panel.animate(rise("translateY(28px)"), { duration: 480 * k, delay: 300 * k, easing: EASE, fill: "both" }),
      ...items.map((item, i) => item.animate(rise("translateY(18px) scale(0.98)"),
        { duration: 420 * k, delay: (420 + i * 60) * k, easing: EASE, fill: "both" }))
    ]
  }

  close() {
    if (!this.isOpen || this.closing) return
    this.closing = true

    const k = this.reduced ? 0 : 1
    const leaving = [
      this.activePanel.animate(
        [{ opacity: 1, transform: "none" }, { opacity: 0, transform: "translateY(20px)" }],
        { duration: 200 * k, easing: EASE, fill: "forwards" }),
      this.panelBarTarget.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 160 * k, fill: "forwards" }),
      this.bloomTarget.animate(
        [{ transform: `scale(${this.bloomScale})`, opacity: 1 }, { transform: "scale(1)", opacity: 0 }],
        { duration: 520 * k, delay: 120 * k, easing: EASE_IN_OUT, fill: "forwards" }),
      this.stageTarget.animate(
        [{ transform: "scale(1.18)", opacity: 0 }, { transform: "none", opacity: 1 }],
        { duration: 520 * k, delay: 140 * k, easing: EASE_IN_OUT, fill: "forwards" })
    ]
    this.animations.push(...leaving)

    Promise.all(leaving.map((animation) => animation.finished))
      .then(() => this.dialogTarget.close())
      .catch(() => { /* cancelled by a disconnect */ })
  }

  // Escape plays the closing animation instead of cutting.
  cancel(event) {
    event.preventDefault()
    this.close()
  }

  // The dialog's close event, also when the browser closes it without asking
  // (a repeated Escape): drop the filled animations and give focus back.
  closed() {
    this.closing = false
    this.cancelAnimations()
    this.hubTarget.focus({ preventScroll: true })
  }

  cancelAnimations() {
    this.animations.forEach((animation) => animation.cancel())
    this.animations = []
  }

  angleAt(event, { x, y }) {
    return (Math.atan2(event.clientY - y, event.clientX - x) * 180) / Math.PI
  }
}
