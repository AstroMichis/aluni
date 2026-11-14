# Passkey sign-up: a display name (and optional email) plus the first passkey.
# POST options mints the WebAuthn user handle and parks the pending account in
# the session; POST create verifies the attestation and creates User + Passkey.
class RegistrationsController < ApplicationController
  include NativeOnly
  include PasskeyCeremony

  allow_unauthenticated_access
  before_action :ensure_signups_open
  before_action :redirect_if_authenticated, only: :new
  layout "public"

  def new
  end

  def options
    display_name = params[:display_name].to_s.strip
    email_address = params[:email_address].to_s.strip.downcase.presence
    return render_error("display_name_required") if display_name.blank?
    return render_error("too_long") if display_name.length > User::NAME_MAX || email_address.to_s.length > User::NAME_MAX

    webauthn_id = WebAuthn.generate_user_id
    options = WebAuthn::Credential.options_for_create(
      user: { id: webauthn_id, name: email_address || display_name, display_name: display_name },
      authenticator_selection: AUTHENTICATOR_SELECTION,
      attestation: "none"
    )
    session[:registration] = {
      "webauthn_id" => webauthn_id, "display_name" => display_name,
      "email_address" => email_address, "challenge" => options.challenge
    }
    render json: options
  end

  def create
    pending = session.delete(:registration)
    return render_error("registration_expired") unless pending

    with_ceremony do
      credential = WebAuthn::Credential.from_create(credential_params)
      credential.verify(pending["challenge"], user_verification: true)

      user = User.transaction do
        User.create!(
          webauthn_id: pending["webauthn_id"], display_name: pending["display_name"],
          email_address: pending["email_address"], locale: I18n.locale.to_s
        ).tap { |u| u.passkeys.create!(passkey_attributes(credential)) }
      end

      start_new_session_for(user)
      render json: { redirect_to: app_root_url }, status: :created
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: "invalid", messages: e.record.errors.full_messages }, status: :unprocessable_content
  end
end
