import { Controller } from "@hotwired/stimulus"

// The field finder's map: Leaflet (vendored 1.9.4, a UMD build loaded lazily with
// `await import("leaflet")`, which attaches window.L), OpenStreetMap tiles with a
// satellite toggle to Esri World Imagery, and one draggable pin (an L.divIcon drawn
// in CSS, no images). Tap moves the pin, arrow keys nudge it while the map has
// focus, + and - zoom. Every move writes the hidden inputs and dispatches
// "field-map:moved" { latitude, longitude, source: "drag" | "tap" | "keys" | "set" }.
//
// The map is built only when the panel shows step 1 ("finder:map-show" -> activate,
// which also runs invalidateSize() when the map already exists, because a map
// created inside a hidden element has no size). "finder:pin" { latitude, longitude,
// zoom } moves the pin and the view (zoom 15 for a picked place or the device);
// asked before the map exists, the request waits for it. The first view is the
// landing's sample field (Ames, Iowa) at zoom 4 until something is chosen. Tiles are
// images, allowed by the CSP (img-src https:); nothing here fetches.
// disconnect() removes the map and every listener.
const OSM_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
const ESRI_URL = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
const OSM_MAX_ZOOM = 19
const ESRI_MAX_ZOOM = 18
const PICK_ZOOM = 15
const NUDGE = 0.05 // of the visible span per arrow press
const ICON_SIZE = [32, 36]
const ICON_ANCHOR = [16, 34]

export default class extends Controller {
  static targets = ["map", "satellite", "hint", "latitude", "longitude"]
  static values = {
    latitude: { type: Number, default: 42.0 },
    longitude: { type: Number, default: -93.75 },
    zoom: { type: Number, default: 4 },
    osmAttribution: { type: String, default: "" },
    esriAttribution: { type: String, default: "" },
    pinLabel: { type: String, default: "" },
    failed: { type: String, default: "" }
  }
  static classes = ["pin"]

  connect() {
    this._connected = true
    this.map = null
    this.marker = null
    this.pending = null
    this.loading = false
    this.satellite = false
  }

  disconnect() {
    this._connected = false
    this.destroy()
  }

  // Action (finder:map-show): build the map, or give it its size now that it is visible.
  async activate() {
    if (this.map) { this.map.invalidateSize(); return }
    if (this.loading || !this.hasMapTarget) return
    this.loading = true
    try {
      await import("leaflet")
      if (!this._connected) return
      if (!window.L) throw new Error("Leaflet did not attach window.L")
      this.build(window.L)
    } catch (error) {
      console.warn("[field-map]", error)
      this.showFailure()
    } finally {
      this.loading = false
    }
  }

  build(L) {
    this.L = L
    const start = this.pending || { latitude: this.latitudeValue, longitude: this.longitudeValue, zoom: this.zoomValue }
    this.map = L.map(this.mapTarget, {
      center: [start.latitude, start.longitude], zoom: start.zoom, keyboard: false, zoomControl: true, attributionControl: true
    })
    this.osm = L.tileLayer(OSM_URL, { maxZoom: OSM_MAX_ZOOM, attribution: this.osmAttributionValue })
    this.esri = L.tileLayer(ESRI_URL, { maxZoom: ESRI_MAX_ZOOM, attribution: this.esriAttributionValue })
    this.osm.addTo(this.map)
    const icon = L.divIcon({ className: this.hasPinClass ? this.pinClass : "", iconSize: ICON_SIZE, iconAnchor: ICON_ANCHOR, html: "" })
    this.marker = L.marker([start.latitude, start.longitude], {
      icon, draggable: true, keyboard: false, autoPan: true, title: this.pinLabelValue, alt: this.pinLabelValue
    }).addTo(this.map)
    this.marker.on("dragend", () => this.moved("drag"))
    this.map.on("click", (event) => { this.marker.setLatLng(event.latlng); this.moved("tap") })
    this.onKeydown = (event) => this.keydown(event)
    this.mapTarget.addEventListener("keydown", this.onKeydown)
    if (this.pending) { this.writeInputs(); this.pending = null }
  }

  // Action (finder:pin): a picked place, the device position or a restored draft.
  pin(event) {
    const { latitude, longitude, zoom } = event.detail || {}
    const lat = Number(latitude)
    const lon = Number(longitude)
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) return
    const level = Number.isFinite(Number(zoom)) ? Number(zoom) : PICK_ZOOM
    if (!this.map) { this.pending = { latitude: lat, longitude: lon, zoom: level }; return }
    this.marker.setLatLng([lat, lon])
    this.map.setView([lat, lon], Math.max(level, this.map.getZoom()))
    this.moved("set")
  }

  toggleSatellite() {
    if (!this.map) return
    this.satellite = !this.satellite
    if (this.satellite) { this.map.removeLayer(this.osm); this.esri.addTo(this.map) }
    else { this.map.removeLayer(this.esri); this.osm.addTo(this.map) }
    if (this.hasSatelliteTarget) this.satelliteTarget.setAttribute("aria-pressed", String(this.satellite))
  }

  // Arrow keys nudge the pin by a twentieth of the view and follow it; + and - zoom.
  keydown(event) {
    if (!this.map || !this.marker) return
    const bounds = this.map.getBounds()
    const dLat = (bounds.getNorth() - bounds.getSouth()) * NUDGE
    const dLon = (bounds.getEast() - bounds.getWest()) * NUDGE
    const { lat, lng } = this.marker.getLatLng()
    let next = null
    switch (event.key) {
      case "ArrowUp": next = [lat + dLat, lng]; break
      case "ArrowDown": next = [lat - dLat, lng]; break
      case "ArrowLeft": next = [lat, lng - dLon]; break
      case "ArrowRight": next = [lat, lng + dLon]; break
      case "+": case "=": event.preventDefault(); this.map.zoomIn(); return
      case "-": case "_": event.preventDefault(); this.map.zoomOut(); return
      default: return
    }
    event.preventDefault()
    next[0] = Math.max(-85, Math.min(85, next[0]))
    this.marker.setLatLng(next)
    this.map.panTo(next)
    this.moved("keys")
  }

  moved(source) {
    const { latitude, longitude } = this.writeInputs()
    if (latitude === null) return
    this.dispatch("moved", { detail: { latitude, longitude, source } })
  }

  writeInputs() {
    if (!this.marker) return { latitude: null, longitude: null }
    const { lat, lng } = this.marker.getLatLng()
    const latitude = lat.toFixed(5)
    const longitude = lng.toFixed(5)
    if (this.hasLatitudeTarget) this.latitudeTarget.value = latitude
    if (this.hasLongitudeTarget) this.longitudeTarget.value = longitude
    return { latitude, longitude }
  }

  // No map (import failed, no window.L): the finder still works through the
  // device position and the search; say so where the map was.
  showFailure() {
    if (this.hasMapTarget) this.mapTarget.hidden = true
    if (this.hasSatelliteTarget) this.satelliteTarget.hidden = true
    if (this.hasHintTarget && this.failedValue) this.hintTarget.textContent = this.failedValue
  }

  destroy() {
    if (this.onKeydown && this.hasMapTarget) this.mapTarget.removeEventListener("keydown", this.onKeydown)
    this.onKeydown = null
    if (this.marker) { this.marker.off(); this.marker = null }
    if (this.map) { this.map.off(); this.map.remove(); this.map = null }
    this.osm = null
    this.esri = null
    this.L = null
  }
}
