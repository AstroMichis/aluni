import { Controller } from "@hotwired/stimulus"

// The scripted landing chat: name, language, passkey. No server call until the
// passkey step, which passkey_controller.js runs on the same element. Opens on
// the mascot's "Let's go" (window "mascot:lets-go"), asks the mascot to dock
// into the header (window "mascot:dock" { selector }), echoes the answers as
// bubbles and resumes from sessionStorage after a reload. Every string comes
// from the view (data-landing-chat-script-value, one set per locale) so picking
// Spanish swaps the remaining lines without a round trip.
const STORAGE_KEY = "aluni.landing-chat"
const STEP_NAME = 0
const STEP_LANGUAGE = 1
const STEP_PASSKEY = 2
const NAME_MAX = 100

export default class extends Controller {
  static targets = [
    "log", "nameForm", "nameInput", "languageStep", "passkeyStep", "displayNameField", "localeField",
    "companion", "companionAvatar", "assistantTemplate", "userTemplate", "createButton", "hint"
  ]
  static values = {
    script: { type: Object, default: {} },
    locale: { type: String, default: "en" }
  }
  static classes = ["open", "waiting"]

  connect() {
    this.onLetsGo = () => this.open()
    this.onDocked = (event) => this.docked(event)
    window.addEventListener("mascot:lets-go", this.onLetsGo)
    window.addEventListener("mascot:docked", this.onDocked)

    // The "welcome back" variant has no script: a finished sign-up leaves nothing to resume.
    if (!this.hasLogTarget) {
      this.state = { step: STEP_NAME, name: "", locale: this.localeValue, open: false }
      this.clearStorage()
      return
    }

    this.state = this.restore()
    if (this.state.open) this.open({ resume: true })
  }

  disconnect() {
    window.removeEventListener("mascot:lets-go", this.onLetsGo)
    window.removeEventListener("mascot:docked", this.onDocked)
  }

  // --- open / close -------------------------------------------------------

  open({ resume = false } = {}) {
    if (!this.element.hidden && !resume) return
    if (resume && this.state.locale && this.scriptValue[this.state.locale]) this.localeValue = this.state.locale

    this.element.hidden = false
    if (this.hasOpenClass) this.element.classList.add(this.openClass)
    this.state.open = true
    this.persist()
    window.dispatchEvent(new CustomEvent("mascot:dock", { detail: { selector: "#landing-chat-companion" } }))
    this.render(resume)
  }

  close() {
    this.element.hidden = true
    if (this.hasOpenClass) this.element.classList.remove(this.openClass)
    if (this.hasWaitingClass) this.element.classList.remove(this.waitingClass)
    this.state.open = false
    this.persist()
    window.dispatchEvent(new CustomEvent("mascot:show"))
  }

  // The mascot landed in the header: with a live canvas the SVG twin steps aside.
  docked(event) {
    if (!this.hasCompanionAvatarTarget) return
    const handoff = event && event.detail ? event.detail.handoff : undefined
    this.companionAvatarTarget.hidden = handoff === "canvas"
  }

  // --- the steps ----------------------------------------------------------

  render(resume) {
    if (!this.hasLogTarget) {
      this.focusFirst()
      return
    }
    if (resume) this.replay()
    else if (this.logTarget.childElementCount === 0) this.say("ask_name")
    this.showStep(this.state.step)
    this.fill()
    this.focusFirst()
  }

  replay() {
    this.logTarget.replaceChildren()
    this.say("ask_name")
    if (this.state.step >= STEP_LANGUAGE) {
      this.echo(this.state.name)
      this.say("nice_to_meet", { name: this.state.name })
      this.say("ask_language")
    }
    if (this.state.step >= STEP_PASSKEY) {
      this.echo(this.t(this.state.locale === "es" ? "spanish" : "english"))
      this.say("ask_passkey")
    }
  }

  submitName(event) {
    event.preventDefault()
    const name = this.hasNameInputTarget ? this.nameInputTarget.value.trim().slice(0, NAME_MAX) : ""
    if (!name) {
      if (this.hasNameInputTarget) this.nameInputTarget.reportValidity()
      return
    }
    this.state.name = name
    this.state.step = STEP_LANGUAGE
    this.persist()
    this.echo(name)
    this.say("nice_to_meet", { name })
    this.say("ask_language")
    this.showStep(STEP_LANGUAGE)
    this.fill()
    this.focusFirst()
  }

  chooseLanguage(event) {
    const button = event.currentTarget
    const locale = button.dataset.locale
    if (!locale || !this.scriptValue[locale]) return
    this.state.locale = locale
    this.state.step = STEP_PASSKEY
    this.persist()
    this.echo(button.textContent.trim())
    this.localeValue = locale
    this.say("ask_passkey")
    this.showStep(STEP_PASSKEY)
    this.fill()
    this.focusFirst()
  }

  localeValueChanged() {
    this.translateStatic()
  }

  // Lines the view rendered in the page locale, re-said in the chosen one.
  translateStatic() {
    if (!Object.keys(this.scriptValue).length) return
    if (this.hasCreateButtonTarget) this.createButtonTarget.textContent = this.t("create_passkey")
    if (this.hasHintTarget) this.hintTarget.textContent = this.t("passkey_hint")
    if (this.hasNameInputTarget) this.nameInputTarget.placeholder = this.t("name_placeholder")
    this.element.setAttribute("lang", this.localeValue)
  }

  showStep(step) {
    if (this.hasNameFormTarget) this.nameFormTarget.hidden = step !== STEP_NAME
    if (this.hasLanguageStepTarget) this.languageStepTarget.hidden = step !== STEP_LANGUAGE
    if (this.hasPasskeyStepTarget) this.passkeyStepTarget.hidden = step !== STEP_PASSKEY
  }

  fill() {
    if (this.hasDisplayNameFieldTarget) this.displayNameFieldTarget.value = this.state.name || ""
    if (this.hasLocaleFieldTarget) this.localeFieldTarget.value = this.state.locale || this.localeValue
  }

  focusFirst() {
    let target = null
    if (this.state.step === STEP_NAME && this.hasNameInputTarget) target = this.nameInputTarget
    else if (this.state.step === STEP_LANGUAGE && this.hasLanguageStepTarget) target = this.languageStepTarget.querySelector("button")
    else if (this.state.step === STEP_PASSKEY && this.hasCreateButtonTarget) target = this.createButtonTarget
    else target = this.element.querySelector("a, button")
    if (target) target.focus({ preventScroll: true })
  }

  // --- the passkey ceremony (passkey_controller.js on the same element) -----

  passkeyStarted() {
    if (this.hasWaitingClass) this.element.classList.add(this.waitingClass)
    window.dispatchEvent(new CustomEvent("mascot:speak", { detail: { chars: 60 } }))
  }

  passkeyFailed() {
    if (this.hasWaitingClass) this.element.classList.remove(this.waitingClass)
  }

  // --- bubbles ------------------------------------------------------------

  say(key, vars = {}) {
    this.bubble(this.hasAssistantTemplateTarget ? this.assistantTemplateTarget : null, this.t(key, vars))
  }

  echo(text) {
    this.bubble(this.hasUserTemplateTarget ? this.userTemplateTarget : null, text)
  }

  bubble(template, text) {
    if (!this.hasLogTarget || !template || !text) return
    const node = template.content.firstElementChild.cloneNode(true)
    const slot = node.querySelector("[data-chat-bubble]") || node
    slot.textContent = text
    this.logTarget.appendChild(node)
    this.logTarget.scrollTop = this.logTarget.scrollHeight
  }

  t(key, vars = {}) {
    const locales = Object.keys(this.scriptValue)
    const strings = this.scriptValue[this.localeValue] || this.scriptValue[locales[0]] || {}
    let text = strings[key] || ""
    for (const [name, value] of Object.entries(vars)) text = text.split(`%{${name}}`).join(value)
    return text
  }

  // --- resume -------------------------------------------------------------

  restore() {
    const empty = { step: STEP_NAME, name: "", locale: this.localeValue, open: false }
    try {
      const raw = sessionStorage.getItem(STORAGE_KEY)
      if (!raw) return empty
      const data = JSON.parse(raw)
      const step = Math.min(STEP_PASSKEY, Math.max(STEP_NAME, Number(data.step) || 0))
      const name = String(data.name || "").slice(0, NAME_MAX)
      const locale = this.scriptValue[data.locale] ? data.locale : this.localeValue
      return { step: name ? step : STEP_NAME, name, locale, open: Boolean(data.open) }
    } catch (_error) {
      return empty
    }
  }

  persist() {
    try {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify(this.state))
    } catch (_error) {
      // Private mode or storage disabled: the chat still works, it just does not resume.
    }
  }

  clearStorage() {
    try {
      sessionStorage.removeItem(STORAGE_KEY)
    } catch (_error) {
      // Nothing to clear.
    }
  }
}
