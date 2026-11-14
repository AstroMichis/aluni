# frozen_string_literal: true

module Notifications
  module Channels
    # The purpose's mailer action with payload[:mailer_args], enqueued. Skipped
    # when the recipient has no email address (it is optional on accounts).
    module Email
      module_function

      def deliver(context)
        address = context.recipient.try(:email_address)
        return Outcome.skipped(:no_email) if address.blank?

        args = Array(context.payload[:mailer_args])
        context.purpose.mailer_class.public_send(context.purpose.mailer_action, *args).deliver_later
        Outcome.sent
      end
    end
  end
end
