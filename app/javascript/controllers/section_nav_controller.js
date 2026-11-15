import { Controller } from "@hotwired/stimulus"

// Sticky chips that jump to each section of a long page and mark the one in
// view. One IntersectionObserver over the sections; the current chip scrolls
// into view inside its own row.
export default class extends Controller {
  static targets = ["link", "section"]
  static classes = ["current"]

  connect() {
    this.observer = new IntersectionObserver((entries) => {
      const visible = entries.filter((entry) => entry.isIntersecting)
      if (visible.length) this.mark(visible[0].target.id)
    }, { rootMargin: "-30% 0px -60% 0px" })
    this.sectionTargets.forEach((section) => this.observer.observe(section))
  }

  disconnect() {
    this.observer?.disconnect()
  }

  mark(id) {
    this.linkTargets.forEach((link) => {
      const current = link.hash === `#${id}`
      link.classList.toggle(this.currentClass, current)
      if (current) {
        link.setAttribute("aria-current", "location")
        link.scrollIntoView({ block: "nearest", inline: "center", behavior: "smooth" })
      } else {
        link.removeAttribute("aria-current")
      }
    })
  }
}
