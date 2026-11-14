# frozen_string_literal: true

module Notifications
  module Channels
    # Native push to the recipient's devices through Action Push Native.
    #
    # Grouping: iOS stacks by `aps.thread-id`, which the gem fills from
    # `thread_id` (the purpose's group key). On FCM the gem maps `thread_id` to
    # `android.collapse_key`, which COLLAPSES instead of grouping, so it is
    # cleared here and the group travels in `data.group` for the Android app.
    #
    # Skipped when the platform's credentials are not set or the recipient has
    # no device for a configured platform; the next channel takes over.
    module Push
      module_function

      def deliver(context)
        platforms = configured_platforms
        return Outcome.skipped(:push_not_configured) if platforms.empty?

        devices = PushDevices.for(context.recipient).select { |d| platforms.include?(d.platform) }
        return Outcome.skipped(:no_push_device) if devices.empty?

        push = (context.payload[:push] || {}).to_h.symbolize_keys
        title, body = PushText.render(context.purpose, context.recipient, context.payload)
        group = context.group

        ApplicationPushNotification.new(
          title: title, body: body, thread_id: group,
          data: { purpose: context.purpose.key, path: push[:path], group: group }.compact,
          google_data: { android: { collapse_key: nil } }
        ).deliver_later_to(devices)

        Outcome.sent(provider_message_id: "devices:#{devices.size}")
      rescue I18n::MissingInterpolationArgument => e
        Outcome.failed("push text: #{e.message}")
      end

      def configured_platforms
        creds = Rails.application.credentials.dig(:action_push_native) || {}
        apns = creds[:apns] || {}
        fcm = creds[:fcm] || {}
        list = []
        list << "apple" if %i[key_id encryption_key team_id topic].all? { |k| apns[k].present? }
        list << "google" if %i[encryption_key project_id].all? { |k| fcm[k].present? }
        list
      end
    end
  end
end
