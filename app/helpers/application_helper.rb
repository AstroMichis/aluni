module ApplicationHelper
  LOCALE_PREFIX = %r{\A/(?:en|es)(?=/|\z)}

  # The current page in another locale, by swapping the path prefix, so the
  # language toggle and the hreflang alternates work on any routed page.
  def localized_path(locale)
    bare = request.path.sub(LOCALE_PREFIX, "")
    bare = "" if bare == "/"
    [ "/#{locale}#{bare}", request.query_string.presence ].compact.join("?")
  end

  def localized_url(locale)
    "#{request.base_url}#{localized_path(locale)}"
  end

  # Strings the passkey Stimulus controller shows, keyed by the server's error codes.
  def passkey_messages
    I18n.t("passkeys.errors").to_json
  end
end
