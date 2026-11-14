# frozen_string_literal: true

# The one way the app sends an automatic message. App code never calls a mailer
# or a push sender directly; it calls the router:
#
#   NotificationRouter.deliver(recipient: user, purpose: :welcome,
#                              payload: { mailer_args: [user, subject, body], push: { path: "/app" } },
#                              idempotency_key: "user:#{user.id}:welcome")
#
# The purpose (config/notification_purposes.yml) names the audience, category,
# grouping and the channels to try in order; the first channel that accepts the
# message wins and the others are not tried. Each attempt is recorded on the
# NotificationDelivery row. Same key twice: once sent, the existing delivery
# comes back and nothing is sent again; a skipped or failed delivery is retried
# in place.
#
# Returns the NotificationDelivery (check #sent?). An unknown purpose raises.
class NotificationRouter
  CHANNELS = {
    "push" => Notifications::Channels::Push,
    "web_push" => Notifications::Channels::WebPush,
    "email" => Notifications::Channels::Email
  }.freeze

  def self.deliver(recipient:, purpose:, idempotency_key:, payload: {})
    new(recipient: recipient, purpose: purpose, payload: payload, idempotency_key: idempotency_key).deliver
  end

  def initialize(recipient:, purpose:, idempotency_key:, payload: {})
    @recipient = recipient
    @purpose = Notifications::Purposes.fetch(purpose)
    @payload = (payload || {}).to_h.symbolize_keys
    @key = idempotency_key.to_s
    raise ArgumentError, "idempotency_key is required" if @key.blank?
  end

  def deliver
    delivery = find_or_create_delivery
    return delivery if delivery.sent?

    delivery.with_lock do
      next if delivery.sent? # a concurrent run won while we waited

      attempts = []
      @purpose.channels.each do |name|
        context = Notifications::Context.new(recipient: @recipient, purpose: @purpose, payload: @payload, delivery: delivery)
        outcome = CHANNELS.fetch(name).deliver(context)
        attempts << { "channel" => name, "result" => outcome.result.to_s, "reason" => outcome.reason }.compact
        next unless outcome.sent?

        delivery.update!(status: :sent, channel: name, sent_at: Time.current, provider_message_id: outcome.provider_message_id,
                         failed_reason: nil, attempts: delivery.attempts + attempts)
        break
      end
      next if delivery.sent?

      status = attempts.any? { |a| a["result"] == "failed" } ? :failed : :skipped
      reason = attempts.map { |a| "#{a['channel']}: #{a['reason']}" }.join("; ")
      delivery.update!(status: status, failed_reason: reason, attempts: delivery.attempts + attempts)
      Rails.logger.info("[NotificationRouter] #{@purpose.key} #{@key} not delivered (#{reason})")
    end
    delivery
  end

  private

  def find_or_create_delivery
    NotificationDelivery.transaction(requires_new: true) do
      NotificationDelivery.create!(purpose: @purpose.key, recipient: @recipient, idempotency_key: @key, status: :queued)
    end
  rescue ActiveRecord::RecordNotUnique
    NotificationDelivery.find_by!(idempotency_key: @key)
  end
end
