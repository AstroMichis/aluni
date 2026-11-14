# Passkey sign-in. GET new renders the page; the Stimulus passkey controller
# then POSTs options (challenge with an empty allow list, so the authenticator
# offers the person's discoverable credentials) and POSTs the assertion to
# create, which opens a Session and answers where to go next.
class SessionsController < ApplicationController
  include NativeOnly
  include PasskeyCeremony

  allow_unauthenticated_access only: %i[new options create]
  before_action :redirect_if_authenticated, only: :new
  layout "public"

  def new
  end

  def options
    options = WebAuthn::Credential.options_for_get(user_verification: "required")
    session[:authentication_challenge] = options.challenge
    render json: options
  end

  def create
    challenge = session.delete(:authentication_challenge)

    with_ceremony do
      credential = WebAuthn::Credential.from_get(credential_params)
      passkey = Passkey.includes(:user).find_by(external_id: credential.id)
      next render_unknown_credential unless passkey && handle_matches?(credential, passkey)

      credential.verify(challenge, public_key: passkey.public_key, sign_count: passkey.sign_count, user_verification: true)
      passkey.touch_usage!(credential.sign_count)
      start_new_session_for(passkey.user)
      render json: { redirect_to: after_authentication_url }
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, status: :see_other, notice: t(".signed_out")
  end

  private

  # Authenticators return the user handle with discoverable credentials; when
  # present it must be the handle we minted for that user.
  def handle_matches?(credential, passkey)
    credential.user_handle.blank? || credential.user_handle == passkey.user.webauthn_id
  end
end
