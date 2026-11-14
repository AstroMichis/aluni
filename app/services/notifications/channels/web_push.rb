# frozen_string_literal: true

module Notifications
  module Channels
    # Browser notifications to the recipient's subscribed browsers (VAPID).
    # Same title and body as the native push (PushText); payload[:push][:url]
    # is the page the notification opens and may be a lambda (resolved only
    # when sent). Skipped when the VAPID keys are not set or no browser is
    # subscribed; the next channel takes over.
    module WebPush
      TTL = 24.hours.to_i

      module_function

      def deliver(context)
        return Outcome.skipped(:web_push_not_configured) unless WebPushConfig.configured?

        recipient = context.recipient
        return Outcome.skipped(:no_web_push_support) unless recipient.respond_to?(:web_push_subscriptions)

        subscriptions = recipient.web_push_subscriptions.to_a
        return Outcome.skipped(:no_browser_subscribed) if subscriptions.empty?

        push = (context.payload[:push] || {}).to_h.symbolize_keys
        title, body = PushText.render(context.purpose, recipient, context.payload)
        url = push[:url].respond_to?(:call) ? push[:url].call : push[:url]
        message = { title: title, body: body, url: url, tag: context.purpose.key }.compact.to_json

        subscriptions.each { |subscription| Notifications::WebPushJob.perform_later(subscription.id, message) }
        Outcome.sent(provider_message_id: "browsers:#{subscriptions.size}")
      rescue I18n::MissingInterpolationArgument => e
        Outcome.failed("web push text: #{e.message}")
      end
    end
  end
end
