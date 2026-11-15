import { Controller } from "@hotwired/stimulus"

// The hover layer of a server-drawn SVG chart: under a finger or the mouse,
// the nearest point gets a crosshair and a tooltip with its date and value.
// Points come as JSON in data-chart-points-value ([{ x, label, value }], x in
// viewBox units). Arrow keys step through the points when the chart has focus.
export default class extends Controller {
  static targets = ["svg", "crosshair", "tooltip"]
  static values = { points: Array, width: Number }

  connect() {
    this.index = -1
  }

  move(event) {
    const rect = this.svgTarget.getBoundingClientRect()
    const x = ((event.clientX - rect.left) / rect.width) * this.widthValue
    let nearest = 0
    this.pointsValue.forEach((point, i) => {
      if (Math.abs(point.x - x) < Math.abs(this.pointsValue[nearest].x - x)) nearest = i
    })
    this.show(nearest)
  }

  key(event) {
    const step = { ArrowRight: 1, ArrowLeft: -1 }[event.key]
    if (!step) return
    event.preventDefault()
    this.show(Math.min(Math.max(this.index + step, 0), this.pointsValue.length - 1))
  }

  hide() {
    this.index = -1
    this.crosshairTarget.style.opacity = 0
    this.tooltipTarget.hidden = true
  }

  show(index) {
    const point = this.pointsValue[index]
    if (!point) return
    this.index = index
    this.crosshairTarget.setAttribute("transform", `translate(${point.x} 0)`)
    this.crosshairTarget.style.opacity = 1

    const tooltip = this.tooltipTarget
    tooltip.hidden = false
    tooltip.querySelector("[data-part=label]").textContent = point.label
    tooltip.querySelector("[data-part=value]").textContent = point.value
    const share = point.x / this.widthValue
    tooltip.style.left = `${share * 100}%`
    tooltip.style.transform = `translateX(${share > 0.7 ? "-100%" : share < 0.3 ? "0" : "-50%"})`
  }
}
