import { Controller } from "@hotwired/stimulus"

// The add-a-field conversation: one question per screen inside one form.
// Next and Back move between steps (a short slide, none with reduced
// motion), the progress bar follows and focus lands on each question. The
// crop grows on the preview plot; the last step lists every answer with a
// way back to its step, then the form is sent and the field is created.
export default class extends Controller {
  static targets = ["step", "progress", "bar", "plot", "review"]
  static classes = ["current"]
  static values = { empty: String, edit: String }

  connect() {
    this.index = 0
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.update()
  }

  next() { this.go(this.index + 1) }
  back() { this.go(this.index - 1) }

  // Enter moves on instead of sending the form early.
  enter(event) {
    if (event.target.tagName === "TEXTAREA" || this.index === this.stepTargets.length - 1) return
    event.preventDefault()
    this.next()
  }

  go(index) {
    if (index < 0 || index >= this.stepTargets.length || index === this.index) return
    const forward = index > this.index
    this.index = index
    if (index === this.stepTargets.length - 1 && this.hasReviewTarget) this.review()
    this.update()

    const step = this.stepTargets[index]
    if (!this.reduced) {
      step.animate(
        [{ opacity: 0, transform: `translateX(${forward ? 24 : -24}px)` }, { opacity: 1, transform: "none" }],
        { duration: 320, easing: "cubic-bezier(0.2, 0.8, 0.2, 1)" }
      )
    }
    step.querySelector("[tabindex='-1']")?.focus({ preventScroll: true })
    window.scrollTo({ top: 0, behavior: this.reduced ? "auto" : "smooth" })
  }

  update() {
    this.stepTargets.forEach((step, i) => {
      step.hidden = i !== this.index
      step.classList.toggle(this.currentClass, i === this.index)
    })
    const last = this.stepTargets.length - 1
    this.barTarget.style.transform = `scaleX(${last ? this.index / last : 1})`
    this.progressTarget.setAttribute("aria-valuenow", this.index + 1)
  }

  // The crop typed or picked (a catalog name in the datalist carries its
  // plant shape) grows in rows on the preview plot; an unknown name grows
  // the generic leafy plant, an empty one leaves the plot bare.
  preview({ target }) {
    if (!this.hasPlotTarget) return
    const option = target.list && [...target.list.options].find((o) => o.value === target.value)
    const shape = target.value.trim() ? (option?.dataset.shape || "leafy") : null
    const plot = this.plotTarget
    plot.classList.remove("plot--empty", "plot--stalk", "plot--grain", "plot--leafy", "plot--bush")
    plot.classList.add(shape ? `plot--${shape}` : "plot--empty")
    if (!shape) return
    plot.querySelectorAll(".plot__plant").forEach((plant) => {
      const fresh = plant.cloneNode()
      fresh.setAttribute("href", `#plot-${shape}`)
      plant.replaceWith(fresh)
    })
  }

  // One row per earlier step: its question, what was answered, and Edit.
  review() {
    const rows = this.stepTargets.slice(0, -1).map((step, index) => {
      const row = document.createElement("div")
      row.className = "review__row"
      const question = document.createElement("dt")
      question.textContent = step.querySelector("h1").textContent
      const answer = document.createElement("dd")
      answer.textContent = this.answersIn(step) || this.emptyValue
      const edit = document.createElement("button")
      edit.type = "button"
      edit.className = "btn btn--ghost btn--sm"
      edit.textContent = this.editValue
      edit.addEventListener("click", () => this.go(index))
      row.append(question, answer, edit)
      return row
    })
    this.reviewTarget.replaceChildren(...rows)
  }

  answersIn(step) {
    const parts = []
    const labelled = (field, text) => {
      const label = field.closest("label")?.querySelector("span")?.textContent.trim()
      return label ? `${label}: ${text}` : text
    }
    step.querySelectorAll("input:checked").forEach((input) => parts.push(input.parentElement.textContent.trim()))
    step.querySelectorAll("input[type=text], input[type=number]").forEach((input) => {
      if (input.value) parts.push(labelled(input, input.value))
    })
    step.querySelectorAll("select").forEach((select) => {
      if (select.value) parts.push(labelled(select, select.selectedOptions[0].textContent))
    })
    return parts.join(" · ")
  }

}
