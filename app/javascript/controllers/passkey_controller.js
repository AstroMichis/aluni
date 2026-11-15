import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Runs a WebAuthn ceremony against the Rails endpoints (PasskeyCeremony):
//   1. POST optionsUrl  -> PublicKeyCredential options (JSON, base64url fields)
//   2. navigator.credentials.create() or .get()
//   3. POST submitUrl   -> { redirect_to } on success, { error, code } otherwise
// mode "create" registers a passkey (sign-up, add a device), "get" signs in.
// The form target, when present, supplies the fields posted with step 1.
export default class extends Controller {
  static targets = ["button", "error", "form"]
  static values = {
    mode: { type: String, default: "get" },
    optionsUrl: String,
    submitUrl: String,
    messages: { type: Object, default: {} }
  }

  connect() {
    // WebAuthn exists only in secure contexts (https, or localhost while
    // developing); a plain-http page over a LAN address has no
    // PublicKeyCredential at all, so name that case before the generic one.
    if (!window.isSecureContext) {
      this.disable()
      this.showError("insecure")
      return
    }
    if (!window.PublicKeyCredential || !navigator.credentials) {
      this.disable()
      this.showError("unsupported")
    }
  }

  async start(event) {
    event?.preventDefault()
    if (this.hasFormTarget && !this.formTarget.reportValidity()) return

    this.clearError()
    this.busy(true)

    try {
      const options = await this.fetchJSON(this.optionsUrlValue, this.formPayload())
      const credential = this.modeValue === "create"
        ? await navigator.credentials.create({ publicKey: this.decodeCreationOptions(options) })
        : await navigator.credentials.get({ publicKey: this.decodeRequestOptions(options) })
      const result = await this.fetchJSON(this.submitUrlValue, { ...this.formPayload(), credential: this.encodeCredential(credential) })
      Turbo.visit(result.redirect_to || "/")
    } catch (error) {
      this.handleError(error)
      this.busy(false)
    }
  }

  // --- wire format -------------------------------------------------------

  formPayload() {
    if (!this.hasFormTarget) return {}
    return Object.fromEntries(new FormData(this.formTarget).entries())
  }

  decodeCreationOptions(options) {
    return {
      ...options,
      challenge: this.toBuffer(options.challenge),
      user: { ...options.user, id: this.toBuffer(options.user.id) },
      excludeCredentials: (options.excludeCredentials || []).map((c) => ({ ...c, id: this.toBuffer(c.id) }))
    }
  }

  decodeRequestOptions(options) {
    return {
      ...options,
      challenge: this.toBuffer(options.challenge),
      allowCredentials: (options.allowCredentials || []).map((c) => ({ ...c, id: this.toBuffer(c.id) }))
    }
  }

  encodeCredential(credential) {
    const response = credential.response
    const encoded = {
      type: credential.type,
      id: credential.id,
      rawId: this.toBase64url(credential.rawId),
      authenticatorAttachment: credential.authenticatorAttachment || null,
      clientExtensionResults: credential.getClientExtensionResults ? credential.getClientExtensionResults() : {},
      response: { clientDataJSON: this.toBase64url(response.clientDataJSON) }
    }

    if (this.modeValue === "create") {
      encoded.response.attestationObject = this.toBase64url(response.attestationObject)
      encoded.response.transports = typeof response.getTransports === "function" ? response.getTransports() : []
    } else {
      encoded.response.authenticatorData = this.toBase64url(response.authenticatorData)
      encoded.response.signature = this.toBase64url(response.signature)
      encoded.response.userHandle = response.userHandle ? this.toBase64url(response.userHandle) : null
    }

    return encoded
  }

  toBuffer(base64url) {
    const padded = base64url.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(base64url.length / 4) * 4, "=")
    return Uint8Array.from(atob(padded), (c) => c.charCodeAt(0)).buffer
  }

  toBase64url(buffer) {
    const bytes = new Uint8Array(buffer)
    let binary = ""
    for (const byte of bytes) binary += String.fromCharCode(byte)
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
  }

  async fetchJSON(url, body) {
    const response = await fetch(url, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
      },
      body: JSON.stringify(body)
    })

    let json = {}
    try { json = await response.json() } catch (_e) { json = {} }

    if (!response.ok) {
      const error = new Error(json.error || "failed")
      error.name = "ServerError"
      error.code = json.error || "failed"
      error.messages = json.messages
      throw error
    }
    return json
  }

  // --- feedback -----------------------------------------------------------

  handleError(error) {
    // The page copy stays friendly; the real reason goes to the console (Web
    // Inspector) because WebKit reports a refused ceremony as NotAllowedError
    // too, for example a web view whose app lacks the webcredentials association.
    console.warn("[passkey]", error.name, error.message)
    if (error.name === "NotAllowedError" || error.name === "AbortError") return this.showError("cancelled")
    if (error.name === "InvalidStateError") return this.showError("already_registered")
    if (error.name === "ServerError") {
      if (error.messages?.length) return this.showText(error.messages.join(", "))
      return this.showError(error.code)
    }
    console.warn("[passkey]", error)
    this.showError("failed")
  }

  showError(code) {
    this.showText(this.messagesValue[code] || this.messagesValue.failed || code)
  }

  showText(text) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = text
    this.errorTarget.classList.add("auth__status--error")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.remove("auth__status--error")
  }

  busy(state) {
    if (this.hasButtonTarget) this.buttonTarget.disabled = state
  }

  disable() {
    if (this.hasButtonTarget) this.buttonTarget.disabled = true
  }
}
