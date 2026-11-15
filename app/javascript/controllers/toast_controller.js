import { Controller } from "@hotwired/stimulus"

// Slides a toast in and removes it after `duration` ms: 4 s for a plain
// message, 6 s when the toast carries an action (an "action" target, such as
// the Undo button under the chat). The countdown pauses while the pointer is
// over the toast or focus is inside it, and resumes when both have left.
const PLAIN_DURATION = 4000
const ACTION_DURATION = 6000
const EXIT_MS = 300

export default class extends Controller {
  static targets = ["action"]
  static values = { duration: Number }

  connect() {
    this.dismissed = false
    this.timeout = null
    this.remaining = this.hasDurationValue ? this.durationValue : (this.hasActionTarget ? ACTION_DURATION : PLAIN_DURATION)

    this.onPause = () => this.pause()
    this.onResume = (event) => this.resume(event)
    this.element.addEventListener("mouseenter", this.onPause)
    this.element.addEventListener("focusin", this.onPause)
    this.element.addEventListener("mouseleave", this.onResume)
    this.element.addEventListener("focusout", this.onResume)

    this.element.classList.add("toast--visible")
    this.start()
  }

  disconnect() {
    this.clear()
    this.element.removeEventListener("mouseenter", this.onPause)
    this.element.removeEventListener("focusin", this.onPause)
    this.element.removeEventListener("mouseleave", this.onResume)
    this.element.removeEventListener("focusout", this.onResume)
  }

  dismiss() {
    this.dismissed = true
    this.clear()
    this.element.classList.remove("toast--visible")
    setTimeout(() => this.element.remove(), EXIT_MS)
  }

  // --- the countdown --------------------------------------------------------

  start() {
    if (this.dismissed) return
    this.startedAt = Date.now()
    this.timeout = setTimeout(() => this.dismiss(), this.remaining)
  }

  pause() {
    if (this.timeout === null) return
    this.clear()
    this.remaining = Math.max(0, this.remaining - (Date.now() - this.startedAt))
  }

  // Resumes only once the pointer has left and nothing inside keeps focus
  // (focus moving between two buttons in the toast fires focusout too).
  resume(event) {
    if (this.timeout !== null || this.dismissed) return
    if (event?.relatedTarget && this.element.contains(event.relatedTarget)) return
    if (this.element.matches(":hover")) return
    if (this.element.contains(document.activeElement)) return
    this.start()
  }

  clear() {
    if (this.timeout !== null) clearTimeout(this.timeout)
    this.timeout = null
  }
}
