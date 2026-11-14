module Notifications
  # Sends one Web Push message to one browser. An expired or invalid
  # subscription is deleted so it is not tried again.
  class WebPushJob < ApplicationJob
    queue_as :push

    def perform(subscription_id, message)
      subscription = WebPushSubscription.find_by(id: subscription_id)
      return unless subscription

      ::WebPush.payload_send(
        message: message,
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh,
        auth: subscription.auth,
        vapid: WebPushConfig.vapid,
        ttl: Channels::WebPush::TTL
      )
      subscription.touch(:last_used_at)
    rescue ::WebPush::ExpiredSubscription, ::WebPush::InvalidSubscription
      subscription.destroy
    end
  end
end
