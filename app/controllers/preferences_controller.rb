# POST /preferences: Aluni's first bubble (language and comfort choices) and
# the small access buttons. Saves the aluni_prefs cookie for everyone and
# users.preferences for a signed-in person. A new language answers with a
# redirect to the same page in that language; anything else with 204, since
# the page already applied the change itself. done=1 marks the intro as seen.
class PreferencesController < ApplicationController
  include LocaleRedirects

  allow_unauthenticated_access

  def update
    prefs = preferences.merge(preference_params)
    prefs = prefs.merge("seen_welcome" => true) if params[:done].present?
    cookies.permanent[Preferences::COOKIE] = { value: prefs.to_cookie, same_site: :lax }
    Current.user.update!(preferences: prefs.to_h) if authenticated?

    new_locale = chosen_locale
    if new_locale && new_locale != I18n.locale.to_s
      cookies.permanent[:locale] = new_locale
      Current.user.update_column(:locale, new_locale) if authenticated?
      return redirect_to locale_redirect_target(new_locale), status: :see_other
    end

    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_back fallback_location: root_path, status: :see_other }
    end
  end

  private

  def preference_params
    params.permit(:theme, :text_size, :motion, :contrast, :read_aloud).to_h
  end

  # params[:locale] is the URL segment; the bubble's choice arrives as preferred_locale.
  def chosen_locale
    value = params[:preferred_locale].to_s
    value if I18n.available_locales.map(&:to_s).include?(value)
  end
end
