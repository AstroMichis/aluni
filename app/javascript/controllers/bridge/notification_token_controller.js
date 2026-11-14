import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Keeps the device's push token registered once the person has allowed push.
// It never asks for permission itself (the native side replies only when push
// is already authorized); asking happens through `bridge--push-permission`.
// Mounted hidden in the app layout with the device-tokens URL as a value.
export default class extends BridgeComponent {
  static component = "notification-token"
  static values = { url: String }

  connect() {
    super.connect()

    if (this.enabled) {
      this.send("connect", {}, (message) => {
        if (message.data && message.data.token) {
          registerToken(this.urlValue, message.data.token, message.data.platform)
        }
      })
    }
  }
}

export async function registerToken(url, token, platform) {
  const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

  await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken, Accept: "application/json" },
    body: JSON.stringify({ token, platform })
  })
}
