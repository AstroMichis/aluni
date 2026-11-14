import { Controller } from "@hotwired/stimulus"

// Native <dialog>: opens as a modal, returns focus to the opener on close.
export default class extends Controller {
  static targets = ["dialog"]
  static values = { open: { type: Boolean, default: false } }

  connect() {
    if (this.openValue) this.open()
  }

  disconnect() {
    this.lastActiveElement = null
  }

  open() {
    this.lastActiveElement = document.activeElement
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
    this.lastActiveElement?.focus()
    this.lastActiveElement = null
  }

  backdropClick(event) {
    const rect = this.dialogTarget.getBoundingClientRect()
    const clickedInside = (
      event.clientX >= rect.left && event.clientX <= rect.right &&
      event.clientY >= rect.top && event.clientY <= rect.bottom
    )
    if (!clickedInside) this.dialogTarget.close()
  }

  closeOnSuccess(event) {
    if (event.detail.success) this.close()
  }
}
