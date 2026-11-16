# The answers from Google, Apple and Microsoft (config/initializers/omniauth.rb).
# OmniAuth's middleware has already checked the state and the provider's proof;
# Auth::SocialSignInService decides who the person is. A sign-in starts a
# session like any other way in; "connect" from the account page links the
# provider to the person already signed in. What the button's form carried (the
# finder's field, the language) waits in session["oauth_pending"].
#
# The provider posts back cross-site, so the callbacks skip Rails' CSRF check:
# OmniAuth's state parameter is the protection there.
class OmniauthCallbacksController < ApplicationController
  include NativeOnly

  allow_unauthenticated_access
  skip_forgery_protection only: %i[callback apple_return]

  ERRORS = %w[email_conflict already_linked signups_closed name_required provider_failed invalid paused].freeze

  def callback
    pending = session.delete("oauth_pending") || {}
    connect = pending["intent"] == "connect" && authenticated?
    result = Auth::SocialSignInService.call(auth: request.env["omniauth.auth"], pending: pending,
                                            current_user: (Current.user if connect))
    I18n.with_locale(locale_from(pending)) { finish(result, connect: connect) }
  end

  # Apple answers with a cross-site form POST, which carries no SameSite=Lax
  # cookie, so the state check would fail there. This page re-posts the same
  # fields to the callback from our own origin, where the cookie travels.
  def apple_return
    @fields = request.request_parameters.slice("code", "state", "id_token", "user", "error")
    render layout: false
  end

  def failure
    session.delete("oauth_pending")
    reason = params[:message].to_s == "paused" ? "paused" : "provider_failed"
    redirect_to (authenticated? ? passkeys_path : sign_in_path), alert: t("omniauth_callbacks.errors.#{reason}"), status: :see_other
  end

  private

  def finish(result, connect:)
    case result
    in Result::Success({ linked: true, user: })
      redirect_to passkeys_path, notice: t("omniauth_callbacks.connected", provider: provider_name), status: :see_other
    in Result::Success({ user: })
      start_new_session_for(user, sign_in_method: params[:provider].to_s)
      cookies.permanent[:locale] = user.locale.presence || I18n.locale.to_s
      flash[:suggest_passkey] = true if user.passkeys.none?
      redirect_to after_authentication_url, status: :see_other
    in Result::Failure({ code: })
      reason = ERRORS.include?(code.to_s) ? code.to_s : "provider_failed"
      redirect_to (connect ? passkeys_path : sign_in_path),
                  alert: t("omniauth_callbacks.errors.#{reason}", provider: provider_name), status: :see_other
    end
  end

  def provider_name = t("omniauth_callbacks.providers.#{params[:provider]}", default: params[:provider].to_s.titleize)

  def locale_from(pending)
    candidate = pending["locale"].to_s
    I18n.available_locales.map(&:to_s).include?(candidate) ? candidate : I18n.locale
  end
end
