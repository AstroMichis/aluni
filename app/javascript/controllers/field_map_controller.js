import { Controller } from "@hotwired/stimulus"

// "Choose on the map": a Leaflet map to place (or correct) the field's pin.
//
// - Leaflet (vendor/javascript/leaflet.js) loads lazily with `await import`,
//   only when the map opens, like Three in the mascot.
// - Layers: EOxCloudless Sentinel-2 mosaic (satellite, default) and the
//   OpenStreetMap standard map. Both are plain HTTPS image tiles, allowed by
//   img-src https: in the CSP; no key, no account.
// - The pin moves by dragging or by tapping the map; for keyboards, the arrow
//   keys pan the map and "Move pin to centre" puts the pin under the centre.
// - "Use this point" dispatches field-map:picked with { latitude, longitude };
//   the chat element routes it to geolocate#fill, which fills the composer's
//   hidden fields (location_source "map") and submits the message.
//
// Opens by itself when the page already has a pin (hasPin value), otherwise
// on the "Choose on the map" button.
const SATELLITE_URL = "https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2025_3857/default/g/{z}/{y}/{x}.jpg"
const SATELLITE_ATTRIBUTION =
  '<a href="https://cloudless.eox.at" target="_blank" rel="noopener">EOxCloudless</a> by EOX IT Services GmbH ' +
  "(Contains modified Copernicus Sentinel data 2025)"
const STREETS_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
const STREETS_ATTRIBUTION =
  '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a> contributors'

export default class extends Controller {
  static targets = ["canvas", "panel", "open", "fallback", "point", "status", "layer"]
  static values = {
    latitude: Number,
    longitude: Number,
    hasPin: Boolean,
    pinTitle: { type: String, default: "" },
    pointTemplate: { type: String, default: "%{latitude}, %{longitude}" },
    unavailable: { type: String, default: "" }
  }

  connect() {
    this._connected = true
    if (this.hasPinValue) this.open()
  }

  disconnect() {
    this._connected = false
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  async open() {
    if (this.map || this._loading) return
    this._loading = true
    if (this.hasPanelTarget) this.panelTarget.hidden = false
    if (this.hasOpenTarget) this.openTarget.hidden = true
    if (this.hasFallbackTarget) this.fallbackTarget.hidden = true

    let L
    try {
      L = await import("leaflet")
    } catch (error) {
      console.warn("[field-map]", error)
      this.report(this.unavailableValue)
      if (this.hasFallbackTarget) this.fallbackTarget.hidden = false
      if (this.hasPanelTarget) this.panelTarget.hidden = true
      if (this.hasOpenTarget) this.openTarget.hidden = false
      this._loading = false
      return
    }
    if (!this._connected) return

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    const start = this.hasPinValue ? [this.latitudeValue, this.longitudeValue] : [10, -40]
    this.map = L.map(this.canvasTarget, {
      center: start,
      zoom: this.hasPinValue ? 15 : 3,
      zoomAnimation: !reduced,
      fadeAnimation: !reduced,
      markerZoomAnimation: !reduced,
      keyboard: true,
      worldCopyJump: true
    })
    this.layers = {
      satellite: L.tileLayer(SATELLITE_URL, { maxNativeZoom: 15, maxZoom: 18, attribution: SATELLITE_ATTRIBUTION }),
      streets: L.tileLayer(STREETS_URL, { maxZoom: 19, attribution: STREETS_ATTRIBUTION })
    }
    this.layers.satellite.addTo(this.map)

    const icon = L.divIcon({ className: "field-map__pin", html: "<span></span>", iconSize: [28, 36], iconAnchor: [14, 34] })
    this.marker = L.marker(start, { draggable: true, icon, title: this.pinTitleValue, alt: this.pinTitleValue }).addTo(this.map)
    this.marker.on("move", () => this.showPoint())
    this.map.on("click", (event) => this.marker.setLatLng(event.latlng))
    this.showPoint()
    this._loading = false
  }

  showLayer(event) {
    const name = event.params.layer
    if (!this.map || !this.layers[name]) return
    Object.entries(this.layers).forEach(([key, layer]) => {
      if (key === name) layer.addTo(this.map)
      else this.map.removeLayer(layer)
    })
    this.layerTargets.forEach((button) => button.setAttribute("aria-pressed", String(button.dataset.fieldMapLayerParam === name)))
  }

  centerPin() {
    if (this.map && this.marker) this.marker.setLatLng(this.map.getCenter())
  }

  use() {
    if (!this.marker) return
    const { lat, lng } = this.marker.getLatLng().wrap()
    this.dispatch("picked", { detail: { latitude: lat.toFixed(5), longitude: lng.toFixed(5) } })
  }

  showPoint() {
    if (!this.hasPointTarget || !this.marker) return
    const { lat, lng } = this.marker.getLatLng().wrap()
    this.pointTarget.textContent = this.pointTemplateValue
      .replace("%{latitude}", lat.toFixed(5))
      .replace("%{longitude}", lng.toFixed(5))
  }

  report(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text || ""
  }
}
