module ApplicationHelper
  LOCALE_PREFIX = %r{\A/(?:en|es)(?=/|\z)}
  SOCIAL_ORDER = %w[google_oauth2 apple microsoft_graph].freeze

  # The social sign-in buttons to offer here: providers with credentials, not
  # paused, in a browser let in (NativeOnly). The shells get them once the
  # system-browser handoff exists (docs/AUTH.md).
  def social_providers
    return [] if !social_shown? || Platform::Switchboard.paused?(:oauth)

    SOCIAL_ORDER & Platform::Features.oauth_providers
  end

  # Every provider, each with whether it works here: the ones without credentials
  # (or while `oauth` is paused) show as disabled placeholders, so the option is
  # visible before the operator configures it. [[provider, available], ...]
  def social_buttons
    return [] unless social_shown?

    live = social_providers
    SOCIAL_ORDER.map { |provider| [ provider, live.include?(provider) ] }
  end

  def social_shown? = !hotwire_native_app? && Platform::Features.native_web_access?

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

  # "ada@example.com" shown back as "a***@example.com": enough to recognise the
  # address a code went to, not enough to read it off someone's screen.
  def masked_email(email)
    local, domain = email.to_s.split("@", 2)
    return email.to_s if local.blank? || domain.blank?

    "#{local[0]}***@#{domain}"
  end
end
