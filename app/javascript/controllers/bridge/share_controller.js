import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Native share sheet inside the app (component "share" in Swift and Kotlin);
// the Web Share API or a copy to the clipboard in a browser.
export default class extends BridgeComponent {
  static component = "share"
  static values = { text: String, url: String, imageUrl: String }

  share(event) {
    event?.preventDefault()
    const payload = { text: this.textValue, url: this.urlValue, imageUrl: this.imageUrlValue }

    if (this.enabled) {
      this.send("share", payload)
    } else if (navigator.share) {
      navigator.share({ text: payload.text, url: payload.url || undefined }).catch(() => {})
    } else if (navigator.clipboard) {
      navigator.clipboard.writeText([payload.text, payload.url].filter(Boolean).join(" "))
    }
  }
}
