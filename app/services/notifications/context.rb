# frozen_string_literal: true

module Notifications
  # Everything a channel needs to send one message.
  Context = Struct.new(:recipient, :purpose, :payload, :delivery, keyword_init: true) do
    def group = purpose.group_for(payload.fetch(:group, {}))
  end
end
