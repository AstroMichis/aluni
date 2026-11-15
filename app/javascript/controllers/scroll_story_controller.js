import { Controller } from "@hotwired/stimulus"
import { reducedMotion } from "preferences/motion"

// Drives the landing tour. Owns the one scroll listener for the page: it works
// out which step sits at the viewport centre and how far through it the reader
// is, marks steps active (once seen, a step stays revealed), keeps the matching
// dot current, and tells the hero scene where the reader is:
//
//   window "landing:progress" { step, progress, heroProgress, scroll }
//   step 0 = hero, 1..n = tour steps, n + 1 = past the last step.
//
// The hero asks for the current state with "landing:sync" once Three is ready.
// Reduced motion: every step is revealed up front and nothing is emitted.
export default class extends Controller {
  static targets = ["step", "dot", "nav"]
  // The view passes its own BEM classes so the controller stays layout-agnostic.
  static classes = ["active", "idle", "current", "inTour"]
  static values = { eventName: { type: String, default: "landing:progress" } }

  connect() {
    this.reduced = reducedMotion()
    this.raf = null
    this.onScroll = this.onScroll.bind(this)
    this.onResize = this.onResize.bind(this)
    this.emit = this.emit.bind(this)

    if (this.reduced) {
      this.stepTargets.forEach((step) => step.classList.add(this.activeClass))
      this.observeSteps()
      return
    }

    if (this.hasIdleClass) this.stepTargets.forEach((step) => step.classList.add(this.idleClass))
    this._connected = true
    this.measure()
    this.observeSteps()

    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onResize)
    window.addEventListener("load", this.onResize)
    window.addEventListener("landing:sync", this.emit)
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(() => { if (this._connected) this.onResize() })
    }
    this.emit()
  }

  // A step becomes active when it covers the middle 10% of the viewport.
  observeSteps() {
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => { if (entry.isIntersecting) this.activate(entry.target) })
    }, { rootMargin: "-45% 0px -45% 0px", threshold: 0 })
    this.stepTargets.forEach((step) => this.observer.observe(step))
  }

  // Offsets are cached here, never read inside the scroll handler.
  measure() {
    this.vh = window.innerHeight || 1
    const y = window.scrollY
    this.bounds = this.stepTargets.map((step) => {
      const rect = step.getBoundingClientRect()
      return { top: rect.top + y, height: rect.height || 1 }
    })
  }

  onScroll() {
    if (this.raf) return
    this.raf = requestAnimationFrame(() => { this.raf = null; this.emit() })
  }

  onResize() {
    if (!this._connected) return
    this.measure()
    this.emit()
  }

  emit() {
    if (!this._connected) return
    const y = window.scrollY
    const center = y + this.vh * 0.5
    const first = this.bounds[0]
    const last = this.bounds[this.bounds.length - 1]
    let step = 0
    let progress = first ? Math.min(1, Math.max(0, y / Math.max(1, first.top - this.vh * 0.5))) : 0

    this.bounds.forEach((bound, i) => {
      if (center >= bound.top) {
        step = i + 1
        progress = Math.min(1, (center - bound.top) / bound.height)
      }
    })
    if (last && center >= last.top + last.height) {
      step = this.bounds.length + 1
      progress = Math.min(1, (center - last.top - last.height) / this.vh)
    }

    const inTour = step >= 1 && step <= this.bounds.length
    if (inTour) this.stepTargets[step - 1].dataset.phase = String(Math.min(3, 1 + Math.floor(progress * 3)))
    if (this.hasInTourClass) this.element.classList.toggle(this.inTourClass, inTour)

    const doc = document.documentElement
    const max = doc.scrollHeight - doc.clientHeight
    window.dispatchEvent(new CustomEvent(this.eventNameValue, {
      detail: { step, progress, heroProgress: Math.min(1, y / this.vh), scroll: max > 0 ? y / max : 0 }
    }))
  }

  activate(step) {
    step.classList.add(this.activeClass)
    if (this.hasIdleClass) step.classList.remove(this.idleClass)
    const index = this.stepTargets.indexOf(step)
    this.dotTargets.forEach((dot, i) => {
      const current = i === index
      if (current) dot.setAttribute("aria-current", "step")
      else dot.removeAttribute("aria-current")
      if (this.hasCurrentClass) dot.classList.toggle(this.currentClass, current)
    })
  }

  disconnect() {
    this._connected = false
    if (this.observer) this.observer.disconnect()
    if (this.raf) cancelAnimationFrame(this.raf)
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onResize)
    window.removeEventListener("load", this.onResize)
    window.removeEventListener("landing:sync", this.emit)
  }
}
