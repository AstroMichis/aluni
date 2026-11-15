# Where to send someone after they change language: the page they came from,
# with the locale prefix swapped, or the root in that locale.
module LocaleRedirects
  extend ActiveSupport::Concern

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
