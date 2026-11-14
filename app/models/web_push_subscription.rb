# A browser that agreed to Web Push notifications for an account. Written by
# App::WebPushSubscriptionsController; removed by Notifications::WebPushJob when
# the push service reports it expired.
class WebPushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, presence: true, uniqueness: { scope: :user_id }, format: { with: %r{\Ahttps://\S+\z} }
  validates :p256dh, :auth, presence: true
end
