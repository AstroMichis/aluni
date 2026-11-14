# frozen_string_literal: true

module Notifications
  # What one channel did with one message: :sent, :skipped (the channel does not
  # apply: no address, no device, switched off) or :failed (it tried and could not).
  Outcome = Struct.new(:result, :reason, :provider_message_id, keyword_init: true) do
    def self.sent(provider_message_id: nil) = new(result: :sent, provider_message_id: provider_message_id)
    def self.skipped(reason) = new(result: :skipped, reason: reason.to_s)
    def self.failed(reason) = new(result: :failed, reason: reason.to_s)

    def sent? = result == :sent
    def failed? = result == :failed
  end
end
