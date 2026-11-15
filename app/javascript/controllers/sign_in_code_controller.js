import { Controller } from "@hotwired/stimulus"

// The emailed code's screens (sign_in_codes/_code_entry and _name). Groups the digits as
// "123 456" while they are typed or pasted, enables Continue once six are in, counts the resend
// cooldown down from resendAfter (seconds; the Resend button stays disabled until it reaches
// zero; the ticking text is a role="timer", not a live region, so it is not read every second)
// and, on connect, hands Aluni's line to read aloud ("speech:read", spoken when the preference
// is on) and to the mascot ("mascot:speak"). Every target is optional: the name step mounts the
// same controller for the line and the focus alone. No fetch: the forms are Turbo's.
const DIGITS = 6
const GROUP = 3
const TICK_MS = 1000

export default class extends Controller {
  static targets = ["line", "input", "continue", "resend", "countdown", "focus"]
  static values = {
    resendAfter: { type: Number, default: 0 },
    resendTemplate: { type: String, default: "" },
    lang: { type: String, default: "" }
  }

  connect() {
    this.interval = null
    this.remaining = Math.max(0, Math.round(this.resendAfterValue))
    this.format()
    this.renderCountdown()
    if (this.remaining > 0) this.interval = setInterval(() => this.tick(), TICK_MS)
    this.speak()
    this.focusFirst()
  }

  disconnect() {
    this.stopCountdown()
  }

  // input->sign-in-code#format: digits only, a space after the third, Continue at six.
  format() {
    if (!this.hasInputTarget) return
    const input = this.inputTarget
    const digits = input.value.replace(/\D/g, "").slice(0, DIGITS)
    const grouped = digits.length > GROUP ? `${digits.slice(0, GROUP)} ${digits.slice(GROUP)}` : digits
    if (input.value !== grouped) input.value = grouped
    if (this.hasContinueTarget) this.continueTarget.disabled = digits.length < DIGITS
  }

  // ── the resend cooldown ────────────────────────────────────────────────

  tick() {
    this.remaining -= 1
    this.renderCountdown()
  }

  renderCountdown() {
    const waiting = this.remaining > 0
    if (this.hasResendTarget) this.resendTarget.disabled = waiting
    if (this.hasCountdownTarget) {
      this.countdownTarget.textContent = waiting ? this.resendTemplateValue.replace("{n}", String(this.remaining)) : ""
    }
    if (!waiting) this.stopCountdown()
  }

  stopCountdown() {
    if (this.interval !== null) clearInterval(this.interval)
    this.interval = null
  }

  // ── Aluni's line and the first field ───────────────────────────────────

  speak() {
    const line = this.hasLineTarget ? this.lineTarget : this.element.querySelector("[data-speak]")
    const text = line ? line.textContent.replace(/\s+/g, " ").trim() : ""
    if (!text) return
    const lang = this.langValue || document.documentElement.lang || "en"
    window.dispatchEvent(new CustomEvent("speech:read", { detail: { text, lang } }))
    window.dispatchEvent(new CustomEvent("mascot:speak", { detail: { chars: text.length } }))
  }

  // The person asked for this screen (Send, or a wrong code), so its field is ready for them.
  focusFirst() {
    const field = this.hasFocusTarget ? this.focusTarget : (this.hasInputTarget ? this.inputTarget : null)
    if (field) field.focus({ preventScroll: true })
  }
}
