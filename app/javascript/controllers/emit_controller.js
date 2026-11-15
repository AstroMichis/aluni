import { Controller } from "@hotwired/stimulus"

// Fires a window event from a plain button or link, so a control anywhere on the page can
// talk to a controller elsewhere (the hero's "Find my field" opens the finder through
// `mascot:lets-go`). data-emit-event-value names the event; the optional detail is JSON.
export default class extends Controller {
  static values = { event: String, detail: { type: Object, default: {} } }

  fire(event) {
    if (!this.eventValue) return
    if (event?.currentTarget?.tagName === "A") event.preventDefault()
    window.dispatchEvent(new CustomEvent(this.eventValue, { detail: this.detailValue }))
  }
}
