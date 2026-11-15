import { Controller } from "@hotwired/stimulus"

// A field's NDVI on a map ("Your field from space"): Esri World Imagery underneath,
// the latest clear scene's NDVI on top (tiles rendered by Planetary Computer's data
// API, coloured red for bare soil to green for a dense crop), and a ring on the pin.
// Leaflet (vendored, UMD, attaches window.L) loads only when the map scrolls into
// view. The toggle shows or hides the NDVI layer; its aria-pressed follows it.
// Tiles are images, allowed by the CSP (img-src https:); nothing here fetches data.
const ESRI_URL = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
const ZOOM = 15
const MAX_ZOOM = 17 // Sentinel-2 and Landsat pixels (10-30 m) turn into blocks beyond this
const OPACITY = 0.7

export default class extends Controller {
  static targets = ["map", "toggle"]
  static values = {
    latitude: Number,
    longitude: Number,
    tiles: String,
    esriAttribution: { type: String, default: "" },
    ndviAttribution: { type: String, default: "" },
    failed: { type: String, default: "" }
  }

  connect() {
    this.map = null
    this.observer = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) { this.observer.disconnect(); this.load() }
    }, { rootMargin: "200px" })
    this.observer.observe(this.mapTarget)
  }

  disconnect() {
    this.observer?.disconnect()
    this.map?.remove()
    this.map = null
  }

  async load() {
    try {
      await import("leaflet")
      if (!this.element.isConnected || !window.L) return
      this.build(window.L)
    } catch (error) {
      console.warn("[ndvi-map]", error)
      if (this.failedValue) this.mapTarget.textContent = this.failedValue
    }
  }

  build(L) {
    const center = [this.latitudeValue, this.longitudeValue]
    this.map = L.map(this.mapTarget, { center, zoom: ZOOM, maxZoom: MAX_ZOOM, scrollWheelZoom: false, attributionControl: true })
    L.tileLayer(ESRI_URL, { maxZoom: MAX_ZOOM, attribution: this.esriAttributionValue }).addTo(this.map)
    this.ndvi = L.tileLayer(this.tilesValue, { maxZoom: MAX_ZOOM, opacity: OPACITY, attribution: this.ndviAttributionValue })
    this.ndvi.addTo(this.map)
    L.circleMarker(center, { radius: 8, weight: 3, color: "#ffffff", fillOpacity: 0, interactive: false }).addTo(this.map)
    this.shown = true
  }

  toggle() {
    if (!this.map) return
    this.shown = !this.shown
    if (this.shown) this.ndvi.addTo(this.map)
    else this.map.removeLayer(this.ndvi)
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-pressed", String(this.shown))
  }
}
