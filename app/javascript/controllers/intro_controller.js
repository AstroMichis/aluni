import { Controller } from "@hotwired/stimulus"

// Aluni's first bubble: language and comfort choices, in character and in place.
// Each toggle applies at once through the preferences controller on <body> (which
// also persists it); a language chip posts preferred_locale and the page reloads in
// that language with the same bubble; "Looks good" marks the intro as seen and
// swaps to the next bubble ("Let's find your field") without a round trip.
export default class extends Controller {
  static targets = ["intro", "start", "form", "sample"]
  static classes = ["hidden"]

  connect() {
    this.onSubmitEnd = (event) => { if (event.detail?.success) this.finish() }
    if (this.hasFormTarget) this.formTarget.addEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  disconnect() {
    if (this.hasFormTarget) this.formTarget.removeEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  // Resolved on every use: the body controller may connect after this one.
  get preferences() {
    return this.application.getControllerForElementAndIdentifier(document.body, "preferences")
  }

  // Pill toggles: data-intro-pref-param="text_size" with data-intro-on-param / data-intro-off-param.
  toggle(event) {
    const button = event.currentTarget
    const { pref, on, off } = event.params
    const pressed = button.getAttribute("aria-pressed") !== "true"
    button.setAttribute("aria-pressed", String(pressed))
    const value = pref === "read_aloud" ? pressed : (pressed ? on : off)
    const preferences = this.preferences
    if (preferences) {
      preferences.set(pref, value)
    } else {
      console.warn("[intro] preferences controller not found")
    }
    if (pref === "read_aloud" && pressed && this.hasSampleTarget) {
      window.dispatchEvent(new CustomEvent("speech:read", { detail: { text: this.sampleTarget.textContent, lang: document.documentElement.lang, force: true } }))
    }
    window.dispatchEvent(new CustomEvent("mascot:speak", { detail: { chars: 40 } }))
  }

  // "Looks good": the form posts done=1 (Turbo); on success swap the bubbles.
  finish() {
    if (this.hasIntroTarget) this.introTarget.hidden = true
    if (this.hasStartTarget) {
      this.startTarget.hidden = false
      const line = this.startTarget.querySelector("[data-speak]")
      if (line) window.dispatchEvent(new CustomEvent("speech:read", { detail: { text: line.textContent, lang: document.documentElement.lang } }))
      window.dispatchEvent(new CustomEvent("mascot:speak", { detail: { chars: line ? line.textContent.length : 30 } }))
      this.startTarget.querySelector("button, a")?.focus()
    }
  }
}
