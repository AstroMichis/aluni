import { Controller } from "@hotwired/stimulus"

// Opens the OS share sheet through navigator.share when available; falls back
// to copying the URL and dispatching `clipboard:copied` so a toast can confirm.
export default class extends Controller {
  static values = { url: String, title: String, text: String }

  async share(event) {
    event?.preventDefault?.()

    const payload = {
      url: this.urlValue,
      title: this.hasTitleValue ? this.titleValue : undefined,
      text: this.hasTextValue ? this.textValue : undefined
    }

    if (navigator.share) {
      try {
        await navigator.share(payload)
      } catch (err) {
        if (err?.name !== "AbortError") this.fallbackCopy()
      }
      return
    }

    this.fallbackCopy()
  }

  fallbackCopy() {
    if (!navigator.clipboard) return
    navigator.clipboard.writeText(this.urlValue)
    this.element.dispatchEvent(new CustomEvent("clipboard:copied", { bubbles: true, detail: { text: this.urlValue } }))
  }
}
