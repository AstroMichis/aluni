import { Controller } from "@hotwired/stimulus"

// Native <dialog>. Modal by default (showModal: top layer, focus trap, backdrop). With
// data-dialog-modal-value="false" it opens with show() and makes the elements matched by
// data-dialog-inert-selector-value inert instead, so another fixed element (the centred
// mascot on the welcome) can still sit above it. Focus returns to the opener on close.
export default class extends Controller {
  static targets = ["dialog"]
  static values = {
    open: { type: Boolean, default: false },
    modal: { type: Boolean, default: true },
    inertSelector: { type: String, default: "" }
  }

  connect() {
    // Turbo keeps a copy of the page for Back; an open dialog would come back
    // open but no longer modal, so it closes before the copy is taken.
    this.closeForCache = () => { if (this.dialogTarget.open) this.close() }
    document.addEventListener("turbo:before-cache", this.closeForCache)
    if (this.openValue) this.open()
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.closeForCache)
    this.setInert(false)
    this.lastActiveElement = null
  }

  open() {
    this.lastActiveElement = document.activeElement
    if (this.modalValue) {
      if (!this.dialogTarget.open) this.dialogTarget.showModal()
    } else {
      if (!this.dialogTarget.open) this.dialogTarget.show()
      this.setInert(true)
      this.dialogTarget.querySelector("[autofocus], button, input, a")?.focus()
    }
  }

  close() {
    this.dialogTarget.close()
    this.setInert(false)
    this.lastActiveElement?.focus()
    this.lastActiveElement = null
  }

  backdropClick(event) {
    const rect = this.dialogTarget.getBoundingClientRect()
    const clickedInside = (
      event.clientX >= rect.left && event.clientX <= rect.right &&
      event.clientY >= rect.top && event.clientY <= rect.bottom
    )
    if (!clickedInside) this.close()
  }

  closeOnSuccess(event) {
    if (event.detail.success) this.close()
  }

  setInert(on) {
    if (!this.inertSelectorValue) return
    document.querySelectorAll(this.inertSelectorValue).forEach((element) => {
      if (on) element.setAttribute("inert", "")
      else element.removeAttribute("inert")
    })
  }
}
