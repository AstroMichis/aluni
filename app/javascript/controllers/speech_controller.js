import { Controller } from "@hotwired/stimulus"

// Read aloud through the browser's own voices: no service, works offline, English and
// Spanish voices come from the device. Lives on <body>. Anything that wants to be read
// dispatches `speech:read` on window with { text, lang, force }; it is spoken when the
// read-aloud preference is on (html[data-read-aloud="true"]) or when force is set (the
// welcome's sample). The first utterance on iOS needs a user gesture, which the toggle
// and the Continue button provide; nothing ever waits on speech.
export default class extends Controller {
  connect() {
    this.synth = window.speechSynthesis || null
    this.voices = []
    this.onRead = (event) => this.read(event.detail || {})
    this.onVisit = () => this.stop()
    this.onVisibility = () => { if (document.hidden) this.stop() }
    this.onVoices = () => this.loadVoices()
    window.addEventListener("speech:read", this.onRead)
    document.addEventListener("turbo:before-visit", this.onVisit)
    document.addEventListener("visibilitychange", this.onVisibility)
    this.synth?.addEventListener?.("voiceschanged", this.onVoices)
    this.loadVoices()
  }

  disconnect() {
    window.removeEventListener("speech:read", this.onRead)
    document.removeEventListener("turbo:before-visit", this.onVisit)
    document.removeEventListener("visibilitychange", this.onVisibility)
    this.synth?.removeEventListener?.("voiceschanged", this.onVoices)
    this.stop()
  }

  get enabled() { return document.documentElement.dataset.readAloud === "true" }

  // Action: reads data-speech-text or the element's own text, regardless of the preference.
  speak(event) {
    const element = event.currentTarget
    this.read({ text: element.dataset.speechText || element.textContent, lang: element.lang, force: true })
  }

  read({ text, lang, force }) {
    if (!this.synth || !text) return
    if (!force && !this.enabled) return
    this.stop()
    const utterance = new SpeechSynthesisUtterance(String(text).replace(/\s+/g, " ").trim())
    utterance.lang = lang || document.documentElement.lang || "en"
    const voice = this.voiceFor(utterance.lang)
    if (voice) utterance.voice = voice
    utterance.rate = 0.95
    try { this.synth.speak(utterance) } catch (error) { console.warn("[speech]", error) }
  }

  stop() {
    if (this.synth && (this.synth.speaking || this.synth.pending)) this.synth.cancel()
  }

  loadVoices() {
    this.voices = this.synth?.getVoices?.() || []
  }

  voiceFor(lang) {
    const prefix = String(lang).slice(0, 2).toLowerCase()
    const matches = this.voices.filter((v) => (v.lang || "").toLowerCase().startsWith(prefix))
    return matches.find((v) => v.default) || matches.find((v) => v.localService) || matches[0] || null
  }
}
