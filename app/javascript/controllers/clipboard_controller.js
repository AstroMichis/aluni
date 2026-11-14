import { Controller } from "@hotwired/stimulus"

// Copies `content` (or the source target's value) and announces it with a
// `clipboard:copied` event a toast can listen to.
export default class extends Controller {
  static values = { content: String }
  static targets = ["source"]

  copy() {
    const text = this.hasContentValue
      ? this.contentValue
      : (this.hasSourceTarget ? this.sourceTarget.value : this.element.value)

    navigator.clipboard?.writeText(text)
    this.element.dispatchEvent(new CustomEvent("clipboard:copied", { bubbles: true, detail: { text } }))
  }
}
