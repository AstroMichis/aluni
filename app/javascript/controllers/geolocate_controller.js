import { Controller } from "@hotwired/stimulus"

// The device position: asks the browser for it, fills the optional latitude/longitude/text
// targets (a composer) and dispatches "geolocate:located" { latitude, longitude, auto } for
// whoever mounts it: the field finder (data-action="geolocate:located->finder#located")
// moves its pin, the chat sends the message. Two ways to ask: a button ("Use my location",
// data-action="geolocate#locate") or the host's own request (finder:locate->geolocate#request,
// fired by the finder when its locate step opens without a pin; `auto` is true in the
// events it ends in). While a request is in flight the optional button target is disabled
// and busy, so the person cannot stack prompts. Failures dispatch "geolocate:failed"
// { auto } and show the view's copy in the status target; nothing is sent. The status target
// may be shared with another controller on the element.
export default class extends Controller {
  static targets = ["latitude", "longitude", "text", "status", "button"]
  static values = {
    template: { type: String, default: "%{latitude}, %{longitude}" },
    denied: { type: String, default: "" },
    unsupported: { type: String, default: "" },
    locating: { type: String, default: "" }
  }

  connect() {
    this._connected = true
    this.pending = false
  }

  disconnect() {
    this._connected = false
    this.pending = false
  }

  // The button.
  locate() {
    this.ask({ auto: false })
  }

  // The host asked on the person's behalf (the finder's locate step opening).
  request() {
    this.ask({ auto: true })
  }

  ask({ auto }) {
    if (this.pending) return
    if (!("geolocation" in navigator)) {
      this.report(this.unsupportedValue || this.deniedValue)
      this.dispatch("failed", { detail: { auto, code: "unsupported" } })
      return
    }
    this.pending = true
    this.busy(true)
    this.report(this.locatingValue)
    navigator.geolocation.getCurrentPosition(
      (position) => this.located(position, auto),
      (error) => this.failed(error, auto),
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 }
    )
  }

  located(position, auto) {
    this.pending = false
    if (!this._connected) return
    this.busy(false)
    const latitude = position.coords.latitude.toFixed(5)
    const longitude = position.coords.longitude.toFixed(5)
    if (this.hasLatitudeTarget) this.latitudeTarget.value = latitude
    if (this.hasLongitudeTarget) this.longitudeTarget.value = longitude
    if (this.hasTextTarget) {
      this.textTarget.value = this.templateValue.replace("%{latitude}", latitude).replace("%{longitude}", longitude)
    }
    this.report("")
    this.dispatch("located", { detail: { latitude, longitude, auto } })
  }

  failed(error, auto) {
    this.pending = false
    if (!this._connected) return
    this.busy(false)
    console.warn("[geolocate]", error && error.code, error && error.message)
    this.report(this.deniedValue)
    this.dispatch("failed", { detail: { auto, code: error && error.code } })
  }

  busy(on) {
    if (!this.hasButtonTarget) return
    this.buttonTarget.disabled = on
    this.buttonTarget.setAttribute("aria-busy", String(on))
  }

  report(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text || ""
  }
}
