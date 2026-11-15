import { Controller } from "@hotwired/stimulus"

// The field finder (pages/home/_finder): three steps in one panel, one visible at a time.
//
//   locate  "Use my location" (geolocate_controller.js), a town search (a GET form into the
//           Turbo Frame #place-results, submit only) and the map (field_map_controller.js).
//           "This is my field" GETs /places/reverse into #place-summary; when the summary
//           arrives with a pin the finder copies its place label, country and region and
//           moves on.
//   basics  crop (free text over a datalist), rainfed or irrigated, an optional area with a
//           unit that defaults from the country.
//   save    signed out: the passkey ceremony (passkey_controller.js on the same element)
//           posts the visible name and the hidden flat inputs this controller fills; signed
//           in: a PATCH form to App::FieldsController with the same hidden inputs.
//
// Opens on window "mascot:lets-go", asks the mascot to dock into #finder-companion and
// hides its own avatar when the live canvas arrives ("mascot:docked" handoff "canvas").
// Escape and the close button hide it ("mascot:show"). Each step's Aluni line
// ([data-speak]) is dispatched as "speech:read" (spoken when read aloud is on) and
// "mascot:speak". The draft lives in sessionStorage ("aluni.finder") so a reload resumes.
// No fetch here: Turbo Frames and forms only.
const STORAGE_KEY = "aluni.finder"
const STEPS = ["locate", "basics", "save"]
const PICK_ZOOM = 15
const NAME_MAX = 100
const COMPANION = "#finder-companion"
const SUMMARY_FRAME = "place-summary"
const RESULTS_FRAME = "place-results"
const CONFIRM_FORM = "finder-confirm"
const SAVE_FORM = "finder-save"
const SOURCES = ["geolocation", "typed", "map"]
const UNITS = ["hectares", "acres"]
const IRRIGATIONS = ["rainfed", "irrigated"]

export default class extends Controller {
  static targets = [
    "body", "step", "heading", "actions", "status", "summary", "map", "lat", "lon", "confirmButton",
    "basicsForm", "saveForm", "field", "avatar", "readAloud", "query"
  ]
  static values = {
    locale: { type: String, default: "en" },
    imperial: { type: Array, default: ["US", "LR", "MM"] },
    located: { type: String, default: "" },
    naming: { type: String, default: "" }
  }
  static classes = ["waiting"]

  connect() {
    this.onLetsGo = () => this.open()
    this.onDocked = (event) => this.docked(event)
    this.onPreferences = (event) => this.preferencesChanged(event)
    this.onVisit = () => this.leaving()
    window.addEventListener("mascot:lets-go", this.onLetsGo)
    window.addEventListener("mascot:docked", this.onDocked)
    window.addEventListener("preferences:changed", this.onPreferences)
    document.addEventListener("turbo:before-visit", this.onVisit)
    this.ceremony = false
    this.opener = null
    this.state = this.restore()
    this.applyState()
    if (this.state.open) this.open({ resume: true })
  }

  disconnect() {
    window.removeEventListener("mascot:lets-go", this.onLetsGo)
    window.removeEventListener("mascot:docked", this.onDocked)
    window.removeEventListener("preferences:changed", this.onPreferences)
    document.removeEventListener("turbo:before-visit", this.onVisit)
  }

  // ── open / close ───────────────────────────────────────────────────────

  open({ resume = false } = {}) {
    if (!this.element.hidden) { this.focusHeading(); return }
    this.opener = resume ? null : document.activeElement
    this.element.hidden = false
    this.state.open = true
    this.showStep(this.state.step, { speak: true })
    window.dispatchEvent(new CustomEvent("mascot:dock", { detail: { selector: COMPANION } }))
  }

  close() {
    if (this.element.hidden) return
    this.element.hidden = true
    this.state.open = false
    this.persist()
    window.dispatchEvent(new CustomEvent("mascot:show"))
    if (this.opener && this.opener.isConnected) this.opener.focus()
    this.opener = null
  }

  // The mascot landed in the header: with a live canvas the SVG twin steps aside.
  docked(event) {
    if (!this.hasAvatarTarget) return
    this.avatarTarget.hidden = Boolean(event.detail && event.detail.handoff === "canvas")
  }

  // ── steps ──────────────────────────────────────────────────────────────

  showStep(name, { speak = false } = {}) {
    if (!STEPS.includes(name)) name = STEPS[0]
    this.state.step = name
    this.stepTargets.forEach((step) => { step.hidden = step.dataset.step !== name })
    this.actionsTargets.forEach((actions) => { actions.hidden = actions.dataset.step !== name })
    if (this.hasSummaryTarget) this.summaryTarget.hidden = name === "locate" || !this.summaryTarget.querySelector("[data-latitude]")
    if (name === "locate" && this.hasMapTarget) this.mapTarget.dispatchEvent(new CustomEvent("finder:map-show"))
    if (name === "save") this.fillSaveForm()
    if (this.hasBodyTarget) this.bodyTarget.scrollTop = 0
    this.persist()
    this.focusHeading()
    if (speak) this.speak()
  }

  back() {
    const index = STEPS.indexOf(this.state.step)
    this.showStep(STEPS[Math.max(0, index - 1)])
  }

  currentStep() {
    return this.stepTargets.find((step) => step.dataset.step === this.state.step)
  }

  focusHeading() {
    const step = this.currentStep()
    const heading = step && this.headingTargets.find((h) => step.contains(h))
    if (heading) heading.focus({ preventScroll: true })
  }

  // Aluni's line for the step: read aloud (when the preference is on) and mouthed by the mascot.
  speak() {
    const step = this.currentStep()
    const line = step && step.querySelector("[data-speak]")
    if (!line) return
    const text = line.textContent.replace(/\s+/g, " ").trim()
    if (!text) return
    window.dispatchEvent(new CustomEvent("speech:read", { detail: { text, lang: this.localeValue } }))
    window.dispatchEvent(new CustomEvent("mascot:speak", { detail: { chars: text.length } }))
  }

  // ── step 1: locate ─────────────────────────────────────────────────────

  // geolocate:located: the device answered.
  located(event) {
    const { latitude, longitude } = event.detail || {}
    this.setPin(latitude, longitude, { source: "geolocation" })
    this.report(this.locatedValue)
  }

  // A result in #place-results (places/_results).
  pickPlace(event) {
    const button = event.currentTarget
    this.setPin(button.dataset.latitude, button.dataset.longitude, { source: "typed" })
    const listbox = button.closest("[role='listbox']")
    if (listbox) listbox.querySelectorAll("[role='option']").forEach((option) => option.setAttribute("aria-selected", String(option === button)))
    this.report("")
    if (this.hasConfirmButtonTarget) this.confirmButtonTarget.focus({ preventScroll: true })
  }

  // field-map:moved: the person dragged, tapped or nudged the pin ("set" echoes our own request).
  moved(event) {
    const { latitude, longitude, source } = event.detail || {}
    if (source === "set") return
    this.setPin(latitude, longitude, { source: "map", tellMap: false })
  }

  // The pin changed: the place is named again on confirm, so the old label goes.
  setPin(latitude, longitude, { source = "map", zoom = PICK_ZOOM, tellMap = true } = {}) {
    const lat = Number(latitude)
    const lon = Number(longitude)
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) return
    this.state.latitude = lat.toFixed(5)
    this.state.longitude = lon.toFixed(5)
    this.state.location_source = SOURCES.includes(source) ? source : "map"
    this.state.place_label = null
    this.state.country_code = null
    this.state.admin_area = null
    this.syncPinInputs()
    if (tellMap && this.hasMapTarget) {
      this.mapTarget.dispatchEvent(new CustomEvent("finder:pin", { detail: { latitude: lat, longitude: lon, zoom } }))
    }
    this.persist()
  }

  syncPinInputs() {
    const placed = Boolean(this.state.latitude && this.state.longitude)
    if (this.hasLatTarget) this.latTarget.value = placed ? this.state.latitude : ""
    if (this.hasLonTarget) this.lonTarget.value = placed ? this.state.longitude : ""
    if (this.hasConfirmButtonTarget) this.confirmButtonTarget.disabled = !placed
  }

  // ── Turbo: the two frames and the save form ────────────────────────────

  submitStarted(event) {
    const form = event.target
    if (form.id === CONFIRM_FORM) this.report(this.namingValue)
    if (form.id === SAVE_FORM) this.waiting(true)
  }

  submitEnded(event) {
    const form = event.target
    if (form.id === CONFIRM_FORM && !(event.detail && event.detail.success)) this.report("")
    if (form.id === SAVE_FORM) {
      this.waiting(false)
      if (event.detail && event.detail.success) this.clearStorage()
    }
  }

  frameLoaded(event) {
    const frame = event.target
    if (frame.id === SUMMARY_FRAME) this.summaryLoaded(frame)
    else if (frame.id === RESULTS_FRAME) {
      const first = frame.querySelector("[role='option']")
      if (first) first.focus({ preventScroll: true })
    }
  }

  // places/_summary arrived: with a pin it carries the place (or a calm line and the
  // coordinates when the geocoder could not name it) and the finder moves on; without one
  // (an invalid spot) its line goes to the status and the person stays on the map.
  summaryLoaded(frame) {
    const place = frame.querySelector("[data-latitude]")
    if (!place) {
      this.report(frame.textContent.replace(/\s+/g, " ").trim())
      return
    }
    const data = place.dataset
    this.state.latitude = Number(data.latitude).toFixed(5)
    this.state.longitude = Number(data.longitude).toFixed(5)
    this.state.place_label = (data.placeLabel || "").slice(0, NAME_MAX) || null
    this.state.country_code = data.countryCode || null
    this.state.admin_area = (data.adminArea || "").slice(0, NAME_MAX) || null
    if (!this.state.unit_chosen) this.state.area_unit = this.imperialValue.includes(this.state.country_code) ? "acres" : "hectares"
    this.syncPinInputs()
    this.applyBasics()
    this.report("")
    this.showStep("basics", { speak: true })
  }

  // ── step 2: basics ─────────────────────────────────────────────────────

  continueBasics(event) {
    event.preventDefault()
    this.readBasics()
    this.showStep("save", { speak: true })
  }

  skipBasics() {
    this.state.crop_name = null
    this.state.irrigation = null
    this.state.area = null
    this.applyBasics()
    this.showStep("save", { speak: true })
  }

  chooseUnit(event) {
    this.state.unit_chosen = true
    this.state.area_unit = UNITS.includes(event.target.value) ? event.target.value : this.state.area_unit
    this.persist()
  }

  readBasics() {
    if (!this.hasBasicsFormTarget) return
    const data = new FormData(this.basicsFormTarget)
    this.state.crop_name = String(data.get("crop_name") || "").trim().slice(0, NAME_MAX) || null
    const irrigation = String(data.get("irrigation") || "")
    this.state.irrigation = IRRIGATIONS.includes(irrigation) ? irrigation : null
    const area = Number(data.get("area"))
    this.state.area = Number.isFinite(area) && area > 0 ? String(data.get("area")) : null
    const unit = String(data.get("area_unit") || "")
    this.state.area_unit = UNITS.includes(unit) ? unit : this.state.area_unit
  }

  applyBasics() {
    if (!this.hasBasicsFormTarget) return
    const form = this.basicsFormTarget
    const crop = form.elements.namedItem("crop_name")
    const area = form.elements.namedItem("area")
    if (crop) crop.value = this.state.crop_name || ""
    if (area) area.value = this.state.area || ""
    form.querySelectorAll("input[name='irrigation']").forEach((radio) => { radio.checked = radio.value === this.state.irrigation })
    form.querySelectorAll("input[name='area_unit']").forEach((radio) => { radio.checked = radio.value === this.state.area_unit })
  }

  // ── step 3: save ───────────────────────────────────────────────────────

  // The hidden flat inputs (sign-up body or the PATCH form) take the draft's values.
  fillSaveForm() {
    this.fieldTargets.forEach((input) => {
      const value = this.state[input.name]
      input.value = value === null || value === undefined ? "" : String(value)
    })
  }

  passkeyStarted() {
    this.ceremony = true
    this.waiting(true)
    window.dispatchEvent(new CustomEvent("mascot:speak", { detail: { chars: 60 } }))
  }

  passkeyFailed() {
    this.ceremony = false
    this.waiting(false)
  }

  // A visit during a ceremony is its success (passkey_controller.js visits /app): the
  // account has the field now, so the draft goes.
  leaving() {
    if (this.ceremony) this.clearStorage()
  }

  waiting(on) {
    if (this.hasWaitingClass) this.element.classList.toggle(this.waitingClass, on)
  }

  // ── status and preferences ─────────────────────────────────────────────

  report(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text || ""
  }

  preferencesChanged(event) {
    if (!this.hasReadAloudTarget || !event.detail || !("read_aloud" in event.detail)) return
    this.readAloudTarget.setAttribute("aria-pressed", String(Boolean(event.detail.read_aloud)))
  }

  // ── the draft ──────────────────────────────────────────────────────────

  applyState() {
    this.syncPinInputs()
    if (this.state.latitude && this.state.longitude && this.hasMapTarget) {
      this.mapTarget.dispatchEvent(new CustomEvent("finder:pin", {
        detail: { latitude: Number(this.state.latitude), longitude: Number(this.state.longitude), zoom: PICK_ZOOM }
      }))
    }
    this.applyBasics()
  }

  empty() {
    return {
      open: false, step: STEPS[0], latitude: null, longitude: null, location_source: null,
      place_label: null, country_code: null, admin_area: null,
      crop_name: null, irrigation: null, area: null, area_unit: "hectares", unit_chosen: false
    }
  }

  restore() {
    const state = this.empty()
    let data = null
    try { data = JSON.parse(sessionStorage.getItem(STORAGE_KEY) || "null") } catch (_error) { return state }
    if (!data || typeof data !== "object") return state
    const lat = Number(data.latitude)
    const lon = Number(data.longitude)
    if (Number.isFinite(lat) && Number.isFinite(lon) && Math.abs(lat) <= 90 && Math.abs(lon) <= 180) {
      state.latitude = lat.toFixed(5)
      state.longitude = lon.toFixed(5)
      state.location_source = SOURCES.includes(data.location_source) ? data.location_source : "map"
      state.place_label = typeof data.place_label === "string" ? data.place_label.slice(0, NAME_MAX) : null
      state.country_code = /^[A-Z]{2}$/.test(String(data.country_code)) ? data.country_code : null
      state.admin_area = typeof data.admin_area === "string" ? data.admin_area.slice(0, NAME_MAX) : null
    }
    state.step = STEPS.includes(data.step) && state.latitude ? data.step : STEPS[0]
    state.open = Boolean(data.open)
    state.crop_name = typeof data.crop_name === "string" ? data.crop_name.slice(0, NAME_MAX) : null
    state.irrigation = IRRIGATIONS.includes(data.irrigation) ? data.irrigation : null
    state.area = Number(data.area) > 0 ? String(data.area) : null
    state.area_unit = UNITS.includes(data.area_unit) ? data.area_unit : "hectares"
    state.unit_chosen = Boolean(data.unit_chosen)
    return state
  }

  persist() {
    try { sessionStorage.setItem(STORAGE_KEY, JSON.stringify(this.state)) } catch (_error) {
      // Private mode or storage disabled: the finder works, it just does not resume.
    }
  }

  clearStorage() {
    try { sessionStorage.removeItem(STORAGE_KEY) } catch (_error) {
      // Nothing to clear.
    }
  }
}
