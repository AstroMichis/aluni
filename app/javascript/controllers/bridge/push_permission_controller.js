import { BridgeComponent } from "@hotwired/hotwire-native-bridge"
import { registerToken } from "controllers/bridge/notification_token_controller"

// Asks the OS for push permission at a moment that makes sense, then registers
// the token. Hidden outside the app, where it has nothing to do.
export default class extends BridgeComponent {
  static component = "push-permission"
  static targets = ["status"]
  static values = { url: String, grantedText: String, deniedText: String }

  connect() {
    super.connect()
    this.element.hidden = !this.enabled
  }

  request(event) {
    event?.preventDefault()
    if (!this.enabled) return

    this.send("request", {}, (message) => {
      const data = message.data || {}
      if (data.token) registerToken(this.urlValue, data.token, data.platform)
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = data.granted ? this.grantedTextValue : this.deniedTextValue
      }
    })
  }
}
