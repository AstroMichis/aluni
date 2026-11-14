# One NotificationRouter.deliver call: which purpose, to whom, which channel
# took it, and what every channel answered (attempts). idempotency_key makes a
# repeated call a no-op once the message was sent.
class NotificationDelivery < ApplicationRecord
  belongs_to :recipient, polymorphic: true

  enum :status, { queued: 0, sent: 1, skipped: 2, failed: 3 }

  validates :purpose, :idempotency_key, presence: true
end
