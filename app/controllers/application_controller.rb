class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # The native shells are exempt: an older Android System WebView would otherwise get a 406.
  allow_browser versions: :modern, unless: :hotwire_native_app?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Runs first so every redirect and flash below carries the request locale.
  prepend_around_action :switch_locale

  helper_method :signups_enabled?

  # The welcome screen's choices (theme, text size, motion, contrast, read aloud):
  # the aluni_prefs cookie for everyone, merged with users.preferences when signed in.
  before_action :load_preferences
  helper_method :preferences

  # The operator paused an outside service (Platform::Switchboard) and this
  # request needed it. Nothing was sent; the visitor gets a calm notice.
  rescue_from Platform::ServicePaused, with: :render_service_paused

  private

  def signups_enabled? = Platform::Features.signups_enabled?

  def preferences = @preferences ||= Preferences.new

  def load_preferences
    prefs = Preferences.from_cookie(cookies[Preferences::COOKIE])
    prefs = prefs.merge(Current.user.preferences) if authenticated? && Current.user.preferences.present?
    @preferences = prefs
  end

  # before_action on RegistrationsController: account creation can ship closed
  # while sign-in stays open (SIGNUPS_ENABLED=0).
  def ensure_signups_open
    return if signups_enabled?

    respond_to do |format|
      format.html { redirect_to sign_in_path, alert: t("signups.disabled_notice") }
      format.any { head :forbidden }
    end
  end

  def render_service_paused(error)
    Rails.logger.info("[platform] #{controller_path}##{action_name} refused: #{error.message}")
    message = t("platform.service_paused")

    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: message }
      format.turbo_stream { redirect_back fallback_location: root_path, alert: message }
      format.json { render json: { error: "service_paused", message: message }, status: :service_unavailable }
      format.any { head :service_unavailable }
    end
  end

  def switch_locale(&action)
    locale = extract_locale || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  # URL prefix, then the cookie, then the signed-in user's choice, then Accept-Language.
  def extract_locale
    parsed = params[:locale]

    # Refresh the cookie whenever the URL carries an explicit locale so a
    # browser without a cookie gets persistence after the first prefixed request.
    if parsed.present? && I18n.available_locales.map(&:to_s).include?(parsed.to_s)
      cookies.permanent[:locale] = parsed.to_s
    end

    parsed = cookies[:locale] if parsed.blank?
    parsed = Current.user&.locale if parsed.blank? && authenticated?
    parsed = request.env["HTTP_ACCEPT_LANGUAGE"]&.scan(/^[a-z]{2}/)&.first if parsed.blank?
    parsed&.to_sym if I18n.available_locales.include?(parsed&.to_sym)
  end

  # ALWAYS include the locale in generated URLs, so every server-rendered link
  # carries /en/ or /es/ and params[:locale] is present on every request.
  def default_url_options
    { locale: I18n.locale }
  end

  # Turns a Result::Failure error hash into a flash string.
  def extract_error_message(error)
    return error unless error.is_a?(Hash)

    error[:messages]&.join(", ") || error[:message] || I18n.t("service_errors.generic")
  end
end
