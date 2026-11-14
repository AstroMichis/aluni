import { Controller } from "@hotwired/stimulus"

const SCROLL_THRESHOLD = 80

// Gives the fixed landing nav a surface once the page has scrolled.
export default class extends Controller {
  connect() {
    this._scrolled = false
    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  onScroll() {
    const y = window.scrollY || document.documentElement.scrollTop || 0
    const next = y > SCROLL_THRESHOLD
    if (next === this._scrolled) return
    this._scrolled = next
    this.element.classList.toggle("landing__nav--scrolled", next)
  }
}
