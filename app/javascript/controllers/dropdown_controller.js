import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.closeHandler = this.close.bind(this)
    document.addEventListener("click", this.closeHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.closeHandler)
  }

  toggle() {
    this.element.classList.toggle("dropdown--open")
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.element.classList.remove("dropdown--open")
    }
  }
}
