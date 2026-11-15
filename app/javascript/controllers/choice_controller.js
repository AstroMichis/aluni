import { Controller } from "@hotwired/stimulus"

// Two equal ways in (sign_in_codes/_choice): the passkey card and the email card, both in the DOM
// and both folded at first, so passkey_controller.js can run its connect-time checks. A tap on a
// head opens that card and folds the other (aria-expanded on the heads, hidden on the bodies, the
// open class on the card); a tap on the open card's head folds it again. Every change is told to
// the page with "choice:picked" { name } ("passkey", "email" or null while both are folded) so the
// finder can show or hide the passkey button in its footer. When this device cannot do passkeys
// (no secure context, no PublicKeyCredential, or the passkey controller already wrote its line
// into the status) the email card opens by default. Remembers nothing: a new page starts from the
// server's state (folded, or the email card open again after an error on that path).
export default class extends Controller {
  static targets = ["card", "passkeyStatus"]
  static classes = ["open"]

  connect() {
    this.apply(this.passkeyUnavailable() ? "email" : this.current())
  }

  // click->choice#pick, with data-choice-name-param on the head button.
  pick(event) {
    const name = event.params.name
    this.apply(name === this.current() ? null : name, { focus: true })
  }

  apply(name, { focus = false } = {}) {
    const cards = this.cardTargets
    if (cards.length === 0) return
    const chosen = cards.find((card) => card.dataset.choiceNameParam === name) || null
    cards.forEach((card) => this.toggle(card, card === chosen))
    if (focus && chosen) this.focusInto(chosen)
    this.dispatch("picked", { detail: { name: chosen ? chosen.dataset.choiceNameParam : null } })
  }

  toggle(card, open) {
    if (this.hasOpenClass) card.classList.toggle(this.openClass, open)
    const head = this.headOf(card)
    if (!head) return
    head.setAttribute("aria-expanded", String(open))
    const body = head.getAttribute("aria-controls") && document.getElementById(head.getAttribute("aria-controls"))
    if (body) body.hidden = !open
  }

  headOf(card) {
    return card.querySelector("[aria-expanded]")
  }

  isOpen(card) {
    const head = this.headOf(card)
    return Boolean(head && head.getAttribute("aria-expanded") === "true")
  }

  current() {
    const open = this.cardTargets.find((card) => this.isOpen(card))
    return open ? open.dataset.choiceNameParam : null
  }

  // After a tap on a head, the first thing to do in the card takes focus (a field or the button).
  focusInto(card) {
    const field = card.querySelector("input:not([type='hidden']), button:not([aria-expanded])")
    if (field) field.focus({ preventScroll: true })
  }

  passkeyUnavailable() {
    if (!window.isSecureContext || !window.PublicKeyCredential || !navigator.credentials) return true
    return this.passkeyStatusTargets.some((status) => status.textContent.trim().length > 0)
  }
}
