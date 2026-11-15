# Passkey sign-up: a display name (and optional email) plus the first passkey.
# POST options mints the WebAuthn user handle and parks the pending account in
# the session; POST create verifies the attestation and creates User + Passkey.
# The field finder posts its pin and basics with the same flat body, so the
# field is parked alongside and written the moment the account exists.
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
      "email_address" => email_address, "challenge" => options.challenge,
      "locale" => chosen_locale, "field" => pending_field
    }
    render json: options
  end

  def create
    pending = session.delete(:registration)
    return render_error("registration_expired") unless pending

    with_ceremony do
      credential = WebAuthn::Credential.from_create(credential_params)
      credential.verify(pending["challenge"], user_verification: true)

      locale = pending["locale"] || I18n.locale.to_s
      user = User.transaction do
        User.create!(
          webauthn_id: pending["webauthn_id"], display_name: pending["display_name"],
          email_address: pending["email_address"], locale: locale
        ).tap do |u|
          u.passkeys.create!(passkey_attributes(credential))
          save_pending_field(u, pending["field"])
        end
      end

      start_new_session_for(user)
      cookies.permanent[:locale] = locale
      render json: { redirect_to: app_root_url(locale: locale) }, status: :created
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: "invalid", messages: e.record.errors.full_messages }, status: :unprocessable_content
  end

  private

  # The language the person picked in the finder, posted in the JSON body. It
  # is read from the body on purpose: params[:locale] is the URL segment of the
  # page the ceremony runs on (/en/sign_up/options), which shadows a body field
  # of the same name. Nil when absent or not offered.
  def chosen_locale
    locale = request.request_parameters["locale"].to_s
    locale if I18n.available_locales.map(&:to_s).include?(locale)
  end

  # The field finder's pin and basics, as the passkey controller posts them: a
  # flat map of every input in its form (latitude, longitude, place_label,
  # country_code, admin_area, location_source, crop_name, irrigation, area,
  # area_unit). Coerced before parking; nil when there is no pin.
  def pending_field
    Fields::SaveSetupService.coerce(request.request_parameters.slice(*Fields::SaveSetupService::KEYS))
  end

  # A field that cannot be saved never blocks the account: log and carry on.
  def save_pending_field(user, field)
    return if field.blank?

    case Fields::SaveSetupService.call(user: user, attributes: field)
    in Result::Success then nil
    in Result::Failure(error)
      Rails.logger.warn("[registrations] field from the finder not saved for user #{user.id}: #{extract_error_message(error)}")
    end
  end
end
