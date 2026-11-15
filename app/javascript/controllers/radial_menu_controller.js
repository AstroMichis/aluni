import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The main menu dial. The rotor turns under a finger or a mouse drag (with
// momentum and a spring that snaps to the nearest section), the mouse wheel,
// a trackpad or the arrow keys. The section under the top marker is the
// selection: the hub in the centre shows its copy and the selected section's
// options appear under the wheel, each one tap from its screen. Tapping a
// wedge turns it to the top; tapping it again, the hub or Enter goes to the
// section's first screen. Every way out blooms a circle from what was tapped
// to cover the screen, then Turbo visits the link.
//
// The URL keeps ?section= in step (replaceState), and the dial starts on the
// sector the server (or Turbo's cached snapshot) marked selected, so coming
// back lands on the section you left.
//
// Angles are degrees. Section i sits at i * step in the rotor's frame, so it
// is under the marker when angle = -i * step. Option lists follow sector order.

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
                    "stage", "options", "bloom"]
  static classes = ["selected", "dragging"]

  connect() {
    this.count = this.sectorTargets.length
    this.step = 360 / this.count
    const start = Math.max(this.sectorTargets.findIndex((s) => s.classList.contains(this.selectedClass)), 0)
    this.angle = this.target = -start * this.step
    this.velocity = this.wheelDelta = 0
    this.index = -1
    this.animations = []
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    this.render()
    this.sync(false)
    // A small turn after the entrance shows the wheel moves.
    if (!this.reduced) this.nudgeTimer = setTimeout(() => this.settleTo(this.target, -170), 1300)
  }

  disconnect() {
    cancelAnimationFrame(this.frame)
    clearTimeout(this.nudgeTimer)
    clearTimeout(this.wheelTimer)
    this.cancelAnimations()
  }

  // Pointer: a press becomes a drag past a few pixels, so taps still click.

  press(event) {
    if (event.button > 0 || this.leaving) return
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
    if (this.leaving) return
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
    else if (event.key === "Enter" || event.key === " ") this.leave(this.hubTarget)
    else return
    event.preventDefault()
    this.interacted()
  }

  // Taps: a wedge turns to the top; the selected wedge goes to its section.

  pick({ params: { index } }) {
    if (this.suppressClick || this.leaving) return
    this.interacted()
    if (index === this.index && Math.abs(this.angle - this.target) < this.step / 2) this.leave(this.hubTarget)
    else this.rotateTo(index)
  }

  // The hub and every option: a plain click blooms out; a modified click
  // (new tab, download) and the click that ends a drag are left alone.
  go(event) {
    if (this.suppressClick) { event.preventDefault(); return }
    if (event.button > 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    this.interacted()
    this.leave(event.currentTarget)
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
    const { tone, kicker, title, description, openLabel, href } = sector.dataset

    this.sectorTargets.forEach((s) => s.classList.toggle(this.selectedClass, s === sector))
    this.element.dataset.tone = tone
    this.dialTarget.setAttribute("aria-valuenow", index + 1)
    this.dialTarget.setAttribute("aria-valuetext", title)
    this.hubTarget.setAttribute("aria-label", openLabel)
    this.hubTarget.setAttribute("href", href)
    const options = this.optionsTargets[index]
    this.optionsTargets.forEach((list) => { list.hidden = list !== options })

    const copy = [[this.kickerTarget, kicker], [this.titleTarget, title], [this.descriptionTarget, description]]
    copy.forEach(([el, text], i) => {
      el.textContent = text
      if (animate && !this.reduced) {
        el.animate(rise(`translateX(${forward ? 10 : -10}px)`), { duration: 280, delay: i * 35, easing: EASE, fill: "backwards" })
      }
    })

    if (animate && !this.reduced) {
      Array.from(options.children).forEach((item, i) => item.animate(rise("translateY(10px)"),
        { duration: 300, delay: 60 + i * 50, easing: EASE, fill: "backwards" }))
    }
    if (animate) this.remember(tone)
    if (this.pointer?.dragging) navigator.vibrate?.(5)
  }

  // ?section= follows the wheel, so Back and a reload land here again.
  remember(tone) {
    const url = new URL(window.location.href)
    url.searchParams.set("section", tone)
    window.history.replaceState(window.history.state, "", url)
  }

  // Leaving: a circle the size of what was tapped grows past the screen's
  // diagonal in the section's tint while the stage zooms away, then Turbo
  // visits the link. Reduced motion goes straight there.

  leave(link) {
    if (this.leaving || !link?.href) return
    this.leaving = true
    clearTimeout(this.nudgeTimer)
    if (this.reduced) { Turbo.visit(link.href); return }

    const rect = link.getBoundingClientRect()
    const size = Math.max(Math.min(rect.width, rect.height), 48)
    const cx = rect.left + rect.width / 2
    const cy = rect.top + rect.height / 2
    const scale = (Math.hypot(window.innerWidth, window.innerHeight) * 2) / size * 1.05
    const bloom = this.bloomTarget
    bloom.dataset.tone = this.sectorTargets[this.index].dataset.tone
    Object.assign(bloom.style, { left: `${cx - size / 2}px`, top: `${cy - size / 2}px`, width: `${size}px`, height: `${size}px` })
    const stage = this.stageTarget.getBoundingClientRect()
    this.stageTarget.style.transformOrigin = `${cx - stage.left}px ${cy - stage.top}px`

    this.cancelAnimations()
    const grow = bloom.animate(
      [{ transform: "scale(1)", opacity: 0.6 }, { transform: `scale(${scale})`, opacity: 1 }],
      { duration: 460, easing: EASE_IN_OUT, fill: "forwards" })
    this.animations = [
      grow,
      this.stageTarget.animate(
        [{ transform: "none", opacity: 1 }, { transform: "scale(1.12)", opacity: 0 }],
        { duration: 400, easing: EASE_IN_OUT, fill: "forwards" })
    ]
    grow.finished.then(() => Turbo.visit(link.href)).catch(() => { /* cancelled by a disconnect */ })
  }

  cancelAnimations() {
    this.animations.forEach((animation) => animation.cancel())
    this.animations = []
  }

  angleAt(event, { x, y }) {
    return (Math.atan2(event.clientY - y, event.clientX - x) * 180) / Math.PI
  }
}
