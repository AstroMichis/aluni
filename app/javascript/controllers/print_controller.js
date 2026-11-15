import { Controller } from "@hotwired/stimulus"

// Opens the browser's print dialog (the report has print styles).
export default class extends Controller {
  print() { window.print() }
}
