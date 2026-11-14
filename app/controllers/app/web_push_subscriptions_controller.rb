module App
  # A browser turns on notifications (web_push_controller.js posts the
  # PushSubscription JSON). One row per account and endpoint.
  class WebPushSubscriptionsController < BaseController
    def create
      data = params.require(:subscription).permit(:endpoint, keys: %i[p256dh auth])
      subscription = Current.user.web_push_subscriptions.find_or_initialize_by(endpoint: data[:endpoint].to_s)
      subscription.assign_attributes(p256dh: data.dig(:keys, :p256dh), auth: data.dig(:keys, :auth),
                                     user_agent: request.user_agent.to_s.first(255))

      if subscription.save
        head :created
      else
        head :unprocessable_content
      end
    end
  end
end
