import { Controller } from "@hotwired/stimulus"

// "Share my location": asks the browser for a position, fills the composer's
// hidden latitude/longitude fields and its text with the fixed line from the
// view, then dispatches "geolocate:located" so the chat sends the message
// (the chat element listens with data-action="geolocate:located->chat#submit").
// Errors show the view's copy in the status line; nothing is sent.
export default class extends Controller {
  static targets = ["latitude", "longitude", "source", "text", "status"]
  static values = {
    template: { type: String, default: "%{latitude}, %{longitude}" },
    pickedTemplate: { type: String, default: "%{latitude}, %{longitude}" },
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
    if (this.hasSourceTarget) this.sourceTarget.value = "geolocation"
    if (this.hasTextTarget) {
      this.textTarget.value = this.templateValue.replace("%{latitude}", latitude).replace("%{longitude}", longitude)
    }
    this.report("")
    this.dispatch("located", { detail: { latitude, longitude } })
  }

  // A point placed on the map (field-map:picked): same composer fields with
  // location_source "map" and the map's own line, then the same submit.
  fill(event) {
    if (!this._connected) return
    const { latitude, longitude } = event.detail || {}
    if (!latitude || !longitude) return
    if (this.hasLatitudeTarget) this.latitudeTarget.value = latitude
    if (this.hasLongitudeTarget) this.longitudeTarget.value = longitude
    if (this.hasSourceTarget) this.sourceTarget.value = "map"
    if (this.hasTextTarget) {
      this.textTarget.value = this.pickedTemplateValue.replace("%{latitude}", latitude).replace("%{longitude}", longitude)
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
