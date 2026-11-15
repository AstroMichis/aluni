import { Controller } from "@hotwired/stimulus"

// One chat bubble. When it lands it scrolls itself into view and, for Aluni's
// lines, tells the mascot to talk (window "mascot:speak" { chars }). Bubbles
// rendered with the page as history are marked silent and do neither.
export default class extends Controller {
  static values = {
    role: { type: String, default: "user" },
    silent: { type: Boolean, default: false }
  }

  connect() {
    if (this.silentValue) return

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.element.scrollIntoView({ block: "end", behavior: reduced ? "auto" : "smooth" })

    if (this.roleValue === "assistant") {
      const chars = this.element.textContent.trim().length
      window.dispatchEvent(new CustomEvent("mascot:speak", { detail: { chars } }))
    }
  }
}
