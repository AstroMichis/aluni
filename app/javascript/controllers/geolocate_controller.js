import { Controller } from "@hotwired/stimulus"

// "Use my location" / "Share my location": asks the browser for a position, fills
// the optional latitude/longitude/text targets (the chat's composer) and dispatches
// "geolocate:located" { latitude, longitude } for whoever mounts it: the field
// finder (data-action="geolocate:located->finder#located") moves its pin, the chat
// sends the message. Errors show the view's copy in the status target; nothing is
// sent. The status target may be shared with another controller on the element.
export default class extends Controller {
  static targets = ["latitude", "longitude", "text", "status"]
  static values = {
    template: { type: String, default: "%{latitude}, %{longitude}" },
    denied: { type: String, default: "" },
    unsupported: { type: String, default: "" },
    locating: { type: String, default: "" }
  }

  connect() {
    this._connected = true
  }

  disconnect() {
    this._connected = false
  }

  locate() {
    if (!("geolocation" in navigator)) {
      this.report(this.unsupportedValue || this.deniedValue)
      return
    }
    this.report(this.locatingValue)
    navigator.geolocation.getCurrentPosition(
      (position) => this.located(position),
      (error) => this.failed(error),
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 }
    )
  }

  located(position) {
    if (!this._connected) return
    const latitude = position.coords.latitude.toFixed(5)
    const longitude = position.coords.longitude.toFixed(5)
    if (this.hasLatitudeTarget) this.latitudeTarget.value = latitude
    if (this.hasLongitudeTarget) this.longitudeTarget.value = longitude
    if (this.hasTextTarget) {
      this.textTarget.value = this.templateValue.replace("%{latitude}", latitude).replace("%{longitude}", longitude)
    }
    this.report("")
    this.dispatch("located", { detail: { latitude, longitude } })
  }

  failed(error) {
    if (!this._connected) return
    console.warn("[geolocate]", error && error.code, error && error.message)
    this.report(this.deniedValue)
  }

  report(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text || ""
  }
}
