import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The onboarding chat. Posts the composer itself so the typing dots show while
// the answer is on its way, then renders the Turbo Stream answer whatever the
// status (a 429 "let us pause" notice arrives as a stream too). Enter sends,
// Shift+Enter breaks the line. Any other form inside the controller with
// data-action="submit->chat#submit" (the quick answers) goes the same way;
// a "geolocate:located" event sends the composer as it stands.
export default class extends Controller {
  static targets = ["form", "input", "log", "typing", "send", "notice"]
  static values = { messages: { type: Object, default: {} } }
  static classes = ["notice"]

  connect() {
    this.abort = new AbortController()
    this.sending = false
    this.onKeydown = this.onKeydown.bind(this)
    if (this.hasInputTarget) this.inputTarget.addEventListener("keydown", this.onKeydown)
    this.scrollToEnd()
  }

  disconnect() {
    this.abort.abort()
    if (this.hasInputTarget) this.inputTarget.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return
    event.preventDefault()
    this.submit()
  }

  async submit(event) {
    if (event && typeof event.preventDefault === "function") event.preventDefault()
    const form = this.formFor(event)
    if (!form || this.sending) return
    if (form === this.composer && !this.inputTarget.value.trim()) {
      this.inputTarget.focus()
      return
    }

    this.sending = true
    this.busy(true)
    this.showTyping(true)
    this.clearNotice()

    try {
      const response = await fetch(form.action, {
        method: "POST",
        body: new FormData(form),
        credentials: "same-origin",
        headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": this.csrfToken() },
        signal: this.abort.signal
      })
      const type = response.headers.get("Content-Type") || ""
      if (type.includes("turbo-stream")) {
        Turbo.renderStreamMessage(await response.text())
        if (form === this.composer) form.reset()
      } else {
        this.showNotice(this.messagesValue.failed)
      }
    } catch (error) {
      if (error.name !== "AbortError") {
        console.warn("[chat]", error)
        this.showNotice(this.messagesValue.failed)
      }
    } finally {
      this.showTyping(false)
      this.busy(false)
      this.sending = false
      if (this.hasInputTarget) this.inputTarget.focus({ preventScroll: true })
      this.scrollToEnd()
    }
  }

  // --- helpers ------------------------------------------------------------

  get composer() {
    return this.hasFormTarget ? this.formTarget : null
  }

  // The form that was submitted when it lives inside the chat, else the composer.
  formFor(event) {
    const target = event && event.target
    if (target instanceof HTMLFormElement && this.element.contains(target)) return target
    return this.composer
  }

  csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.content : ""
  }

  showTyping(state) {
    if (this.hasTypingTarget) this.typingTarget.hidden = !state
    if (state) this.scrollToEnd()
  }

  busy(state) {
    if (this.hasSendTarget) this.sendTarget.disabled = state
    if (this.hasInputTarget) this.inputTarget.readOnly = state
  }

  scrollToEnd() {
    if (this.hasLogTarget) this.logTarget.scrollTop = this.logTarget.scrollHeight
  }

  showNotice(text) {
    if (!this.hasNoticeTarget || !text) return
    const line = document.createElement("p")
    line.setAttribute("role", "status")
    if (this.hasNoticeClass) line.classList.add(...this.noticeClasses)
    line.textContent = text
    this.noticeTarget.replaceChildren(line)
  }

  clearNotice() {
    if (this.hasNoticeTarget) this.noticeTarget.replaceChildren()
  }
}
