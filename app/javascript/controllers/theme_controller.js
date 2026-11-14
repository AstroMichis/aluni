import { Controller } from "@hotwired/stimulus"

// Toggles html[data-theme] between dark (default) and light; remembers the choice.
export default class extends Controller {
  connect() {
    const saved = localStorage.getItem("theme")
    if (saved) document.documentElement.dataset.theme = saved
  }

  toggle() {
    const html = document.documentElement
    html.dataset.theme = html.dataset.theme === "dark" ? "light" : "dark"
    localStorage.setItem("theme", html.dataset.theme)
  }
}
