import { Controller } from "@hotwired/stimulus"

// Slides a flash message in, removes it after `duration` ms.
export default class extends Controller {
  static values = { duration: { type: Number, default: 4000 } }

  connect() {
    this.element.classList.add("toast--visible")
    this.timeout = setTimeout(() => this.dismiss(), this.durationValue)
  }

  dismiss() {
    this.element.classList.remove("toast--visible")
    setTimeout(() => this.element.remove(), 300)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
