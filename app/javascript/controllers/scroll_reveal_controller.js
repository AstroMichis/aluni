import { Controller } from "@hotwired/stimulus"

// Adds the visible class once the element scrolls into view; with reduced
// motion it is visible from the start.
export default class extends Controller {
  static classes = ["visible"]

  connect() {
    const visible = this.hasVisibleClass ? this.visibleClass : "landing__reveal--visible"

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.element.classList.add(visible)
      return
    }

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add(visible)
          this.observer.unobserve(entry.target)
        }
      })
    }, { threshold: 0.1 })

    this.observer.observe(this.element)
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }
}
