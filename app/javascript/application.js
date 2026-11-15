// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Leaving a page or a tab while a lazy Turbo Frame is still loading (the
// rotation's "why" texts) aborts its fetch on purpose; that rejection is not
// an error, so it stays out of the console. Anything else still surfaces.
window.addEventListener("unhandledrejection", (event) => {
  if (event.reason?.name === "AbortError") event.preventDefault()
})
