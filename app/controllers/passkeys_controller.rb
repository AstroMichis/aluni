# A signed-in person's passkeys: list them, add one for another device, remove
# one (never the last, which would lock the account).
class PasskeysController < ApplicationController
  include NativeOnly
  include PasskeyCeremony

  layout "application"

  def index
    @passkeys = Current.user.passkeys.order(:created_at)
  end

  def options
    user = Current.user
    options = WebAuthn::Credential.options_for_create(
      user: { id: user.webauthn_id, name: user.email_address.presence || user.display_name, display_name: user.display_name },
      exclude: user.passkeys.pluck(:external_id),
      authenticator_selection: AUTHENTICATOR_SELECTION,
      attestation: "none"
    )
    session[:creation_challenge] = options.challenge
    render json: options
  end

  def create
    challenge = session.delete(:creation_challenge)

    with_ceremony do
      credential = WebAuthn::Credential.from_create(credential_params)
      credential.verify(challenge, user_verification: true)
      Current.user.passkeys.create!(passkey_attributes(credential))
      render json: { redirect_to: passkeys_url }, status: :created
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: "invalid", messages: e.record.errors.full_messages }, status: :unprocessable_content
  end

  def destroy
    passkey = Current.user.passkeys.find(params[:id])

    if Current.user.passkeys.count <= 1
      redirect_to passkeys_path, alert: t(".last_passkey"), status: :see_other
    else
      passkey.destroy
      redirect_to passkeys_path, notice: t(".removed"), status: :see_other
    end
  end
end
