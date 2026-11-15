# An account signs in with a passkey, an emailed code or a linked provider
# account (Identity: Google, Apple, Microsoft): no password, no required email.
# webauthn_id is the opaque user handle authenticators return with a
# discoverable credential; display_name is what the person is called.
class User < ApplicationRecord
  NAME_MAX = 100

  has_many :sessions, dependent: :destroy
  has_many :passkeys, dependent: :destroy
  has_many :identities, dependent: :destroy
  has_many :auth_handoffs, dependent: :delete_all
  has_many :device_tokens, dependent: :destroy
  has_many :web_push_subscriptions, dependent: :destroy
  has_many :notification_deliveries, as: :recipient, dependent: :destroy
  has_one :farmer_profile, dependent: :destroy
  has_one :onboarding_session, dependent: :destroy
  has_many :farms, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.to_s.strip.downcase.presence }

  before_validation :assign_webauthn_id, on: :create

  validates :webauthn_id, presence: true, uniqueness: true
  validates :display_name, presence: true, length: { maximum: NAME_MAX }
  validates :email_address, uniqueness: true, length: { maximum: NAME_MAX }, allow_nil: true
  validates :locale, inclusion: { in: ->(_user) { I18n.available_locales.map(&:to_s) } }

  def onboarding_complete? = onboarding_session&.completed? || false

  private

  def assign_webauthn_id
    self.webauthn_id ||= WebAuthn.generate_user_id
  end
end
