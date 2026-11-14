# frozen_string_literal: true

module Notifications
  # The recipient's push devices as ApplicationPushDevice rows. Shells register
  # tokens in device_tokens (bridge `notification-token`); before a push they are
  # mirrored into action_push_native_devices (ios -> apple, android -> google).
  # A token removed from device_tokens is removed here too; a token APNs/FCM
  # reject is destroyed by the gem.
  module PushDevices
    PLATFORMS = { "ios" => "apple", "android" => "google" }.freeze

    module_function

    def for(recipient)
      sync(recipient)
      ApplicationPushDevice.where(owner: recipient).to_a
    end

    def sync(recipient)
      return unless recipient.respond_to?(:device_tokens)

      wanted = recipient.device_tokens.reload.filter_map do |t|
        platform = PLATFORMS[t.platform.to_s]
        [ platform, t.token ] if platform && t.token.present?
      end
      wanted.each do |platform, token|
        device = ApplicationPushDevice.find_or_initialize_by(platform: platform, token: token)
        device.update!(owner: recipient) if device.new_record? || device.owner != recipient
      rescue ActiveRecord::RecordNotUnique
        next
      end
      ApplicationPushDevice.where(owner: recipient).where.not(token: wanted.map(&:last)).delete_all
    end
  end
end
