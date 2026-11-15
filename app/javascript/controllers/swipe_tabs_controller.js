import { Controller } from "@hotwired/stimulus"
import { reducedMotion } from "preferences/motion"

// Swipe between a screen's tabs on a touch screen (on <body> in
// layouts/app_screen): left for the next tab, right for the previous one.
// The tabs are whatever .screen__tabs the page shows (a field's workspace or
// a section's tabs); a swipe clicks the tab's own link, so Turbo moves the
// frame or the page exactly as a tap would. A field-workspace tab slides in
// from the side it came from.
//
// Left alone: gestures that start on the painted map, sliders, fields, or
// anything that scrolls sideways, near the screen edges (the native back
// gesture), mostly vertical ones (scrolling), and slow drags.

const MIN_DISTANCE = 60   // px across
const MAX_SLOPE = 0.6     // |dy| / |dx|
const MAX_TIME = 600      // ms
const EDGE = 24           // px kept for the system's edge gestures
const IGNORE = "input, select, textarea, button, .crop-map, .chart, [data-swipe-ignore]"

export default class extends Controller {
  connect() {
    this.start = this.start.bind(this)
    this.end = this.end.bind(this)
    this.slide = this.slide.bind(this)
    this.element.addEventListener("touchstart", this.start, { passive: true })
    this.element.addEventListener("touchend", this.end, { passive: true })
    document.addEventListener("turbo:frame-render", this.slide)
  }

  disconnect() {
    this.element.removeEventListener("touchstart", this.start)
    this.element.removeEventListener("touchend", this.end)
    document.removeEventListener("turbo:frame-render", this.slide)
  }

  start(event) {
    const touch = event.touches[0]
    this.touch = null
    if (event.touches.length > 1 || !document.querySelector(".screen__tabs")) return
    if (touch.clientX < EDGE || touch.clientX > window.innerWidth - EDGE) return
    if (event.target.closest(IGNORE) || this.scrollsSideways(event.target)) return
    this.touch = { x: touch.clientX, y: touch.clientY, time: event.timeStamp }
  }

  end(event) {
    const from = this.touch
    this.touch = null
    if (!from) return
    const touch = event.changedTouches[0]
    const dx = touch.clientX - from.x
    const dy = touch.clientY - from.y
    if (Math.abs(dx) < MIN_DISTANCE || Math.abs(dy) > Math.abs(dx) * MAX_SLOPE || event.timeStamp - from.time > MAX_TIME) return
    this.go(dx < 0 ? 1 : -1)
  }

  go(step) {
    const tabs = [...document.querySelectorAll(".screen__tabs a")]
    const current = tabs.findIndex((tab) => tab.getAttribute("aria-current") === "page")
    const next = tabs[current + step]
    if (current < 0 || !next) return
    this.direction = step
    next.click()
  }

  // The new tab's content comes in from the side the swipe pointed to.
  slide(event) {
    const step = this.direction
    this.direction = null
    if (!step || reducedMotion()) return
    const content = event.target.querySelector("main") || event.target
    content.animate([{ opacity: 0, transform: `translateX(${step * 32}px)` }, { opacity: 1, transform: "none" }],
                    { duration: 240, easing: "cubic-bezier(0.2, 0.8, 0.2, 1)" })
  }

  scrollsSideways(element) {
    for (let node = element; node && node !== this.element; node = node.parentElement) {
      if (node.scrollWidth > node.clientWidth + 1 && /(auto|scroll)/.test(getComputedStyle(node).overflowX)) return true
    }
    return false
  }
}
