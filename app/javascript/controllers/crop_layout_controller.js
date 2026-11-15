import { Controller } from "@hotwired/stimulus"
import { allocate, GRID, SIDE } from "fields/cell_layout"
import { reducedMotion } from "preferences/motion"

// "Plan the planting": how a season splits a field between crops. Two ways
// in, always in step:
//   - numbers: each crop's area (or percent) by typing or sliding; the map
//     re-places the cells with the same rule as the server (fields/cell_layout)
//   - the map: pick a crop (its swatch) or the eraser, then tap or drag over
//     the 10x10 grid with a finger or a mouse, or move with the arrow keys and
//     press Space; the areas follow the painted cells.
// The cells travel in a hidden input per crop; without JavaScript the form
// still posts the numbers and the server places the cells.

const EPSILON = 0.005

export default class extends Controller {
  static targets = ["list", "row", "template", "grid", "cell", "amount", "percent", "slider", "cells",
                    "total", "submit", "add", "shortcuts", "brushes"]
  static values = { total: Number, unit: String, max: Number, previous: Array, messages: Object }

  connect() {
    this.format = new Intl.NumberFormat(document.documentElement.lang || undefined, { maximumFractionDigits: 2 })
    this.cells = this.rowTargets.map((row) => this.readCells(row))
    this.brush = 0
    this.shortcutsTarget.hidden = false
    this.brushesTarget.hidden = false
    // Rows without cells yet (a fresh season) get them from their numbers.
    if (this.cells.some((list, i) => list.length === 0 && this.share(i) > 0)) this.place()
    this.refresh()
  }

  // Numbers

  resize(event) {
    const i = this.rowIndex(event.target)
    this.sliderTargets[i].value = event.target.value
    this.place()
    this.refresh()
  }

  slide(event) {
    const i = this.rowIndex(event.target)
    this.amountTargets[i].value = this.round(Number(event.target.value))
    this.place()
    this.refresh()
  }

  rename() {
    this.refresh()
  }

  // Rows

  add() {
    if (this.rowTargets.length >= this.maxValue) return
    const row = this.templateTarget.content.firstElementChild.cloneNode(true)
    this.listTarget.append(row)
    this.cells.push([])
    this.brush = this.rowTargets.length - 1
    this.refresh()
    row.querySelector("input[type=text]").focus()
    if (!reducedMotion()) row.animate([{ opacity: 0, transform: "translateY(8px)" }, { opacity: 1, transform: "none" }], { duration: 240, easing: "ease-out" })
  }

  remove(event) {
    if (this.rowTargets.length === 1) {
      this.amountTargets[0].value = ""
      this.rowTargets[0].querySelector("input[type=text]").value = ""
      this.cells = [[]]
    } else {
      const i = this.rowIndex(event.target)
      this.rowTargets[i].remove()
      this.cells.splice(i, 1)
      if (this.brush >= i) this.brush = Math.max(this.brush - 1, 0)
    }
    this.refresh()
  }

  // Shortcuts

  equal() {
    const n = this.rowTargets.length
    this.amountTargets.forEach((input) => { input.value = this.round(this.totalValue / n) })
    this.cells = this.cells.map(() => [])
    this.place()
    this.refresh()
  }

  copy() {
    this.load(this.previousValue)
  }

  // Each crop of last season moves onto the ground the next one had.
  swap() {
    const last = this.previousValue
    this.load(last.map((crop, i) => {
      const from = last[(i + 1) % last.length]
      return { crop: crop.crop, share: from.share, cells: from.cells }
    }))
  }

  load(crops) {
    while (this.rowTargets.length < crops.length) this.listTarget.append(this.templateTarget.content.firstElementChild.cloneNode(true))
    while (this.rowTargets.length > crops.length) this.rowTargets[this.rowTargets.length - 1].remove()
    crops.forEach((crop, i) => {
      this.rowTargets[i].querySelector("input[type=text]").value = crop.crop
      this.amountTargets[i].value = this.round(crop.share * this.totalValue)
      this.sliderTargets[i].value = this.amountTargets[i].value
    })
    this.cells = crops.map((crop) => [...crop.cells])
    this.brush = 0
    this.refresh()
  }

  // The map: the brush is a crop's index, or -1 for the eraser.

  pick(event) {
    this.brush = Number(event.currentTarget.dataset.brush ?? event.currentTarget.value)
    this.refresh()
  }

  press(event) {
    if (event.button > 0) return
    const cell = this.cellAt(event)
    if (!cell) return
    event.preventDefault()
    this.gridTarget.setPointerCapture(event.pointerId)
    this.painting = event.pointerId
    this.paint(cell)
  }

  drag(event) {
    if (this.painting !== event.pointerId) return
    const cell = this.cellAt(event)
    if (cell && cell !== this.lastCell) this.paint(cell)
  }

  lift(event) {
    if (this.painting !== event.pointerId) return
    this.painting = null
    this.lastCell = null
  }

  key(event) {
    const cell = event.target.closest("[data-index]")
    if (!cell) return
    const index = Number(cell.dataset.index)
    const moves = { ArrowRight: 1, ArrowLeft: -1, ArrowDown: SIDE, ArrowUp: -SIDE, Home: -(index % SIDE), End: SIDE - 1 - (index % SIDE) }
    if (event.key in moves) {
      const next = index + moves[event.key]
      const sameRow = Math.floor(next / SIDE) === Math.floor(index / SIDE)
      if (next < 0 || next >= GRID || (Math.abs(moves[event.key]) === 1 && !sameRow)) return
      event.preventDefault()
      this.focusCell(next)
    } else if (event.key === " " || event.key === "Enter") {
      event.preventDefault()
      this.paint(cell)
    }
  }

  paint(cell) {
    this.lastCell = cell
    const index = Number(cell.dataset.index)
    const owner = this.cells.findIndex((list) => list.includes(index))
    if (owner === this.brush) return
    if (this.brush >= this.rowTargets.length) return
    if (owner >= 0) this.cells[owner] = this.cells[owner].filter((c) => c !== index)
    if (this.brush >= 0) this.cells[this.brush].push(index)
    ;[owner, this.brush].filter((i) => i >= 0).forEach((i) => this.followCells(i))
    this.refresh()
  }

  // A painted crop's area is its cells.
  followCells(i) {
    const value = this.round((this.cells[i].length / GRID) * this.totalValue)
    this.amountTargets[i].value = value || ""
    this.sliderTargets[i].value = value
  }

  // Drawing

  place() {
    this.cells = allocate(this.rowTargets.map((_, i) => this.share(i)), this.cells)
  }

  refresh() {
    const names = this.rowTargets.map((row, i) => row.querySelector("input[type=text]").value.trim() || this.message("unnamed", { number: i + 1 }))
    const slotOf = new Array(GRID).fill(null)
    this.cells.forEach((list, i) => list.forEach((c) => { slotOf[c] = i }))

    this.rowTargets.forEach((row, i) => {
      row.dataset.slot = i
      row.querySelector(".crop-swatch").dataset.slot = i
      const radio = row.querySelector("input[name=brush]")
      radio.value = i
      radio.checked = i === this.brush
      this.cellsTargets[i].value = this.cells[i].join(",")
      const share = this.share(i)
      this.percentTargets[i].textContent = share > 0 ? `${Math.round(share * 100)}%` : ""
    })
    this.drawBrushes(names)

    this.cellTargets.forEach((cell) => {
      const index = Number(cell.dataset.index)
      const slot = slotOf[index]
      cell.dataset.slot = slot ?? ""
      cell.setAttribute("aria-label", this.message("cell", {
        row: Math.floor(index / SIDE) + 1, col: (index % SIDE) + 1, crop: slot === null ? this.message("empty") : names[slot]
      }))
    })

    this.addTarget.hidden = this.rowTargets.length >= this.maxValue
    this.summarise()
  }

  // A chip per crop above the map, so the crop you paint with stays in view.
  drawBrushes(names) {
    const eraser = this.brushesTarget.querySelector("[data-brush='-1']")
    const chips = [...this.brushesTarget.querySelectorAll("[data-brush]:not([data-brush='-1'])")]
    chips.slice(names.length).forEach((chip) => chip.remove())
    names.forEach((name, i) => {
      let chip = chips[i]
      if (!chip) {
        chip = document.createElement("button")
        chip.type = "button"
        chip.className = "planner__chip"
        chip.dataset.brush = i
        chip.dataset.action = "crop-layout#pick"
        const swatch = document.createElement("span")
        swatch.className = "crop-swatch"
        swatch.dataset.slot = i
        swatch.setAttribute("aria-hidden", "true")
        chip.append(swatch, document.createElement("span"))
        eraser.before(chip)
      }
      chip.lastElementChild.textContent = name
    })
    this.brushesTarget.querySelectorAll("[data-brush]").forEach((chip) => {
      chip.setAttribute("aria-pressed", Number(chip.dataset.brush) === this.brush)
    })
  }

  // What is left unplanted, or by how much the crops run over the field.
  summarise() {
    const used = this.rowTargets.reduce((sum, _, i) => sum + this.share(i), 0)
    const over = used > 1 + EPSILON
    const left = Math.max(1 - used, 0)
    let text
    if (over) text = this.message("over", { area: this.amountText((used - 1) * this.totalValue) })
    else if (left < EPSILON) text = this.message("full")
    else text = this.message("left", { area: this.amountText(left * this.totalValue), percent: `${Math.round(left * 100)}%` })
    this.totalTarget.textContent = text
    this.totalTarget.classList.toggle("planner__total--over", over)
    this.submitTarget.disabled = over
    this.amountTargets.forEach((input) => input.setAttribute("aria-invalid", over))
  }

  // Helpers

  share(i) {
    const value = Number(this.amountTargets[i]?.value)
    return value > 0 && this.totalValue > 0 ? value / this.totalValue : 0
  }

  readCells(row) {
    const value = row.querySelector("input[name='crops[][cells]']").value
    return value ? value.split(",").map(Number).filter(Number.isInteger) : []
  }

  rowIndex(element) {
    return this.rowTargets.indexOf(element.closest("[data-crop-layout-target~='row']"))
  }

  cellAt(event) {
    const element = document.elementFromPoint(event.clientX, event.clientY)
    const cell = element?.closest("[data-index]")
    return cell && this.gridTarget.contains(cell) ? cell : null
  }

  focusCell(index) {
    this.cellTargets.forEach((cell) => { cell.tabIndex = -1 })
    const cell = this.cellTargets[index]
    cell.tabIndex = 0
    cell.focus()
  }

  round(value) {
    return Math.round(value * 100) / 100
  }

  amountText(value) {
    return `${this.format.format(this.round(value))} ${this.unitValue}`.replace(" %", "%")
  }

  message(key, values = {}) {
    return Object.entries(values).reduce((text, [k, v]) => text.replaceAll(`%{${k}}`, v), this.messagesValue[key] || "")
  }
}
