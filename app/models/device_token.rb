# A native push token registered by a shell (bridge `notification-token`).
class DeviceToken < ApplicationRecord
  belongs_to :user

  enum :platform, { ios: 0, android: 1 }

  validates :token, presence: true, uniqueness: { scope: :platform }
  validates :platform, presence: true
end
