# frozen_string_literal: true

module Notifications
  # Title and body of a push, in the recipient's locale, from the purpose's
  # push_key (notifications.push.<key>.title/body). Shared by native and web push.
  module PushText
    module_function

    def render(purpose, recipient, payload)
      return [ nil, nil ] if purpose.push_key.blank?

      push = (payload[:push] || {}).to_h.symbolize_keys
      locale = recipient.try(:locale).presence || I18n.default_locale
      I18n.with_locale(locale) do
        [ I18n.t("notifications.push.#{purpose.push_key}.title", **(push[:title] || {}).to_h.symbolize_keys),
          I18n.t("notifications.push.#{purpose.push_key}.body", **(push[:body] || {}).to_h.symbolize_keys) ]
      end
    end
  end
end
