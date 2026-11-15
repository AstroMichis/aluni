import { Controller } from "@hotwired/stimulus"

// The person's preferences (theme, text size, motion, contrast, read aloud) on <body>.
// Turbo keeps <html> across visits and swaps the body, so connect() re-applies the
// server-rendered values to <html> on every page. Toggles update <html> at once and
// persist through the hidden form in shared/_preferences_form (a Turbo submission to
// /preferences that sets the cookie and, when signed in, the account).
export default class extends Controller {
  static targets = ["form", "readAloudButton"]
  static values = {
    theme: { type: String, default: "dark" },
    textSize: { type: String, default: "normal" },
    motion: { type: String, default: "full" },
    contrast: { type: String, default: "normal" },
    readAloud: { type: Boolean, default: false }
  }

  connect() {
    this.migrateLegacyTheme()
    this.apply()
  }

  apply() {
    const html = document.documentElement
    html.dataset.theme = this.themeValue
    html.dataset.textSize = this.textSizeValue
    html.dataset.motion = this.motionValue
    html.dataset.contrast = this.contrastValue
    html.dataset.readAloud = String(this.readAloudValue)
    this.readAloudButtonTargets.forEach((button) => button.setAttribute("aria-pressed", String(this.readAloudValue)))
  }

  toggleTheme() { this.set("theme", this.themeValue === "dark" ? "light" : "dark") }
  toggleReadAloud() { this.set("read_aloud", !this.readAloudValue) }

  cycleTextSize() {
    const order = ["normal", "large", "larger"]
    this.set("text_size", order[(order.indexOf(this.textSizeValue) + 1) % order.length])
  }

  // name is the server-side key (theme, text_size, motion, contrast, read_aloud).
  set(name, value) {
    const property = name.replace(/_(\w)/g, (_, c) => c.toUpperCase()) + "Value"
    this[property] = value
    this.apply()
    this.persist(name, value)
    window.dispatchEvent(new CustomEvent("preferences:changed", { detail: { [name]: value } }))
  }

  persist(name, value) {
    if (!this.hasFormTarget) return
    const field = this.formTarget.elements.namedItem(name)
    if (field) field.value = String(value)
    this.formTarget.requestSubmit()
  }

  // The old theme controller kept the choice in localStorage; carry it over once.
  migrateLegacyTheme() {
    let saved = null
    try { saved = localStorage.getItem("theme"); localStorage.removeItem("theme") } catch (_e) { return }
    if (saved && saved !== this.themeValue && (saved === "dark" || saved === "light")) {
      this.themeValue = saved
      this.persist("theme", saved)
    }
  }
}
