# Shared pieces of the WebAuthn ceremonies (SessionsController,
# RegistrationsController, PasskeysController). The browser side is
# app/javascript/controllers/passkey_controller.js; both speak the JSON shapes
# of the WebAuthn Level 3 spec (PublicKeyCredential.toJSON()).
module PasskeyCeremony
  extend ActiveSupport::Concern

  # Discoverable, user-verified credentials: no username to type, a biometric
  # or device PIN confirms the person.
  AUTHENTICATOR_SELECTION = {
    resident_key: "required",
    require_resident_key: true,
    user_verification: "required"
  }.freeze

  private

  # The credential exactly as the browser serialises it. A missing `credential`
  # or `response` key answers 400 through ActionController::ParameterMissing.
  def credential_params
    params.require(:credential).tap { |c| c.require(:response) }.permit(
      :type, :id, :rawId, :authenticatorAttachment,
      response: [ :attestationObject, :clientDataJSON, :authenticatorData, :signature, :userHandle, { transports: [] } ],
      clientExtensionResults: {}
    ).to_h
  end

  # Wraps decode + verify + persist. Anything the gem raises for a bad or stale
  # ceremony (WebAuthn::Error family, bare RuntimeError on type/id mismatch,
  # ArgumentError on malformed base64, NoMethodError on a malformed shape)
  # answers 422 with a stable code; the payload is never logged.
  def with_ceremony
    yield
  rescue WebAuthn::Error, ArgumentError, TypeError, RuntimeError, NoMethodError => e
    Rails.logger.info("[passkeys] #{controller_path}##{action_name} ceremony failed: #{e.class}")
    render json: { error: "verification_failed", code: e.class.name.demodulize.underscore }, status: :unprocessable_content
  end

  def render_error(code, status: :unprocessable_content)
    render json: { error: code }, status: status
  end

  def render_unknown_credential
    render_error("unknown_credential", status: :unauthorized)
  end

  def passkey_attributes(credential)
    transports = credential.response.respond_to?(:transports) ? Array(credential.response.transports) : []
    nickname = params[:nickname].to_s.strip.first(User::NAME_MAX).presence || t("passkeys.default_nickname")

    { external_id: credential.id, public_key: credential.public_key, sign_count: credential.sign_count,
      transports: transports, nickname: nickname }
  end
end
