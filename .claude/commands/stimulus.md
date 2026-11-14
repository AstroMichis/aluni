# /stimulus -- Stimulus Controller Builder

You are creating a Stimulus controller for Aluni. The request is: $ARGUMENTS

## Before writing code:

1. Read `docs/RAILS_PATTERNS.md`, Hotwire section, and `docs/DESIGN_SYSTEM.md`
2. Read `app/javascript/controllers/toast_controller.js` (simplest: timers + cleanup)
3. Read `app/javascript/controllers/dialog_controller.js` (native `<dialog>`, focus return)
4. Read `app/javascript/controllers/passkey_controller.js` (fetch, feedback, values as an Object)
5. Read `app/javascript/controllers/hero_scene_controller.js` (Three.js lifecycle, lazy import, full disposal)
6. Read `app/javascript/controllers/bridge/share_controller.js` (a Hotwire Native bridge component)

## Controller template

```javascript
// app/javascript/controllers/<name>_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["element"]                       // data-<name>-target="element"
  static values  = { key: { type: String, default: "" } }   // data-<name>-key-value
  static classes = ["active"]                        // data-<name>-active-class

  connect() {
    // set up state, observers, initial render
  }

  disconnect() {
    // ALWAYS clean up everything you created in connect():
    if (this.timeout) clearTimeout(this.timeout)
    if (this.interval) clearInterval(this.interval)
    if (this.animationId) cancelAnimationFrame(this.animationId)
    if (this.observer) this.observer.disconnect()
    if (this.outsideClick) document.removeEventListener("click", this.outsideClick)
  }

  toggle() {                                         // data-action="click-><name>#toggle"
    this.elementTarget.hidden = !this.elementTarget.hidden
  }
}
```

## Critical rules

- **Stimulus handles interactivity, Turbo handles server communication.** Toggle, animate, validate locally, manage UI state. Do not fetch application data; use Turbo Frames and Streams. The exceptions are ceremonies and bridge replies (`passkey_controller.js`, `bridge/*`), which POST JSON with the CSRF token from `meta[name=csrf-token]`.
- **Clean up in `disconnect()`.** Turbo navigations disconnect and reconnect controllers; a leaked listener runs twice. Bind handlers once in `connect()` and remove the same reference.
- **Auto-registration.** `pin_all_from "app/javascript/controllers"`: name the file `<name>_controller.js`; subfolders become `folder--name` (`bridge/share_controller.js` is `bridge--share`).
- **No npm, no bundler.** A library is vendored with `bin/importmap pin <package>` (or copied into `vendor/javascript`) and heavy ones load lazily: `const THREE = await import("three")` behind a `_connected` check.
- **Reduced motion.** Check `window.matchMedia("(prefers-reduced-motion: reduce)")` before any animation; reveal the final state instead.
- **BEM-agnostic.** A controller receives class names from the view through `static classes`, never hardcodes a block name.
- **Native bridge components** import `BridgeComponent` from `@hotwired/hotwire-native-bridge`, declare `static component = "name"` matching the Swift and Kotlin components exactly, check `this.enabled` before `send()`, and fall back to a web behaviour.

## Common patterns

Native `<dialog>`: `this.dialogTarget.showModal()` / `.close()`, return focus to the opener, close on a click outside the dialog's rect (`dialog_controller.js`).

Click outside to close:
```javascript
connect() { this.outsideClick = (e) => { if (!this.element.contains(e.target)) this.close() }; document.addEventListener("click", this.outsideClick) }
disconnect() { document.removeEventListener("click", this.outsideClick) }
```

Debounce:
```javascript
search() { clearTimeout(this.timeout); this.timeout = setTimeout(() => this.performSearch(), 300) }
```

Turbo Stream fetch (chat-like interfaces):
```javascript
const response = await fetch(this.element.action, { method: "POST", body: new FormData(this.element),
  headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content } })
if (response.ok) Turbo.renderStreamMessage(await response.text())
```

Three.js: see `hero_scene_controller.js`: lazy import, try/catch init, renderer size caps, pixel ratio per device, rAF-debounced resize, clock paused when hidden, theme observer, dispose every geometry/material and the renderer in `disconnect()`.

## Event syntax

`click->controller#method`, `input->controller#search`, `change->controller#update`, `keydown.enter->controller#submit`, `keydown.escape->controller#close`, `submit->controller#handleSubmit`, `turbo:submit-end->controller#reset`.

## Testing

Stimulus is exercised through `spec/system` (Cuprite, `js_errors: true`: any uncaught exception fails the example) and request specs for the server side. Keep a system spec that mounts the controller on a real page (`spec/system/landing_spec.rb` is the model). Never Playwright, Puppeteer or npx.
