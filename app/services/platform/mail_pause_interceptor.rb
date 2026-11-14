# frozen_string_literal: true

module Platform
  # ActionMailer interceptor: drops outgoing mail while the operator has `mail`
  # paused. Mail carrying the critical header always goes out, so an operator
  # is never locked out of something only email can unblock.
  module MailPauseInterceptor
    CRITICAL_HEADER = "X-Platform-Critical"

    module_function

    def delivering_email(message)
      return if message.header[CRITICAL_HEADER].present?
      return unless Switchboard.paused?(:mail)

      message.perform_deliveries = false
      Rails.logger.info("[platform] mail to #{Array(message.to).size} recipient(s) dropped: mail paused")
    end
  end
end
