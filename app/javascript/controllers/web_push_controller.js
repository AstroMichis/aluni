import { Controller } from "@hotwired/stimulus"

// Web Push opt-in: registers the service worker, asks for permission and posts
// the subscription to `url`. On iPhone, Web Push works only from a page added
// to the home screen, so outside it we explain how instead.
export default class extends Controller {
  static targets = ["prompt", "done", "denied", "install"]
  static values = { url: String, publicKey: String }

  connect() {
    if (!this.supported) {
      if (this.isIos && !this.standalone) this.show(this.installTarget)
      else this.element.hidden = true
      return
    }
    if (Notification.permission === "granted") this.subscribe()
    else if (Notification.permission === "denied") this.show(this.deniedTarget)
    else this.show(this.promptTarget)
  }

  async enable() {
    const permission = await Notification.requestPermission()
    if (permission === "granted") await this.subscribe()
    else this.show(this.deniedTarget)
  }

  async subscribe() {
    try {
      const registration = await navigator.serviceWorker.register("/service-worker.js", { scope: "/" })
      const ready = await navigator.serviceWorker.ready
      const subscription = (await ready.pushManager.getSubscription()) ||
        (await ready.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: this.applicationServerKey }))
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken, Accept: "application/json" },
        body: JSON.stringify({ subscription: subscription.toJSON() })
      })
      this.show(response.ok ? this.doneTarget : this.promptTarget)
      return registration
    } catch (_error) {
      this.show(this.promptTarget)
    }
  }

  show(target) {
    for (const element of [this.promptTarget, this.doneTarget, this.deniedTarget, this.installTarget]) {
      element.hidden = element !== target
    }
    this.element.hidden = false
  }

  get supported() {
    return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window
  }

  get isIos() {
    return /iPad|iPhone|iPod/.test(navigator.userAgent)
  }

  get standalone() {
    return window.navigator.standalone === true || window.matchMedia("(display-mode: standalone)").matches
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  get applicationServerKey() {
    const padding = "=".repeat((4 - (this.publicKeyValue.length % 4)) % 4)
    const base64 = (this.publicKeyValue + padding).replace(/-/g, "+").replace(/_/g, "/")
    return Uint8Array.from(atob(base64), (char) => char.charCodeAt(0))
  }
}
