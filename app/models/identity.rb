# A provider account linked to a user: Google, Apple or Microsoft through
# OmniAuth (Auth::SocialSignInService). uid is the provider's stable subject id;
# email is what the provider reported, and email_verified whether Aluni trusts it
# (Google and Apple vouch for it, Microsoft is never trusted for linking).
class Identity < ApplicationRecord
  PROVIDERS = %w[google_oauth2 apple microsoft_graph].freeze

  belongs_to :user

  scope :verified, -> { where(email_verified: true) }

  validates :provider, inclusion: { in: PROVIDERS }
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :provider, uniqueness: { scope: :user_id }
  validates :email, :name, length: { maximum: User::NAME_MAX }, allow_nil: true

  def touch_usage!
    update!(last_used_at: Time.current)
  end
end
