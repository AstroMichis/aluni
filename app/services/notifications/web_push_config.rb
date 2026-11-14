# frozen_string_literal: true

module Notifications
  # The VAPID key pair browsers use to trust our pushes, from credentials
  # (web_push.public_key / private_key / subject). Generate a pair with
  # `bin/rails web_push:vapid_keys` and add it to the credentials yourself.
  module WebPushConfig
    module_function

    def configured? = %i[public_key private_key subject].all? { |key| settings[key].present? }

    def public_key = settings[:public_key]

    def vapid = { subject: settings[:subject], public_key: settings[:public_key], private_key: settings[:private_key] }

    def settings = (Rails.application.credentials.dig(:web_push) || {}).to_h.symbolize_keys
  end
end
