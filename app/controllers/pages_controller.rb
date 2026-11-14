# The informational web site (public layout) and the locale switcher.
class PagesController < ApplicationController
  allow_unauthenticated_access
  layout "public"

  def home
  end

  # GET /locale/:new_locale: persist the choice and go back where the person
  # was, with the prefix swapped.
  def set_locale
    locale = params[:new_locale].to_s
    return head :not_found unless I18n.available_locales.map(&:to_s).include?(locale)

    cookies.permanent[:locale] = locale
    Current.user&.update_column(:locale, locale) if authenticated?
    redirect_to locale_redirect_target(locale), status: :see_other
  end

  private

  def locale_redirect_target(locale)
    uri = URI.parse(request.referer.to_s)
    return root_path(locale: locale) unless uri.host == request.host

    prefix = %r{\A/(#{I18n.available_locales.join('|')})(?=/|\z)}
    path = uri.path.sub(prefix, "")
    "/#{locale}#{path}#{"?#{uri.query}" if uri.query.present?}"
  rescue URI::InvalidURIError
    root_path(locale: locale)
  end
end
