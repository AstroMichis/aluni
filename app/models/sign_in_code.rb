# One sign-in code sent by email (by text later): the hashed code, its window,
# the attempts so far, and whatever was parked for a sign-up (name, locale, the
# finder's field). The services in app/services/auth/ own every transition.
class SignInCode < ApplicationRecord
  MAX_ATTEMPTS = 5
  TTL = 10.minutes
  RESEND_AFTER = 60.seconds

  enum :channel, { email: 0, sms: 10 }, prefix: true

  scope :live, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }

  validates :destination, :code_digest, :expires_at, presence: true
  validates :locale, inclusion: { in: ->(_code) { I18n.available_locales.map(&:to_s) } }
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def live? = consumed_at.nil? && expires_at.future?
  def exhausted? = attempts >= MAX_ATTEMPTS
  def verified? = verified_at.present?
  def used? = used_at.present?

  # Seconds until another code may be requested for this address.
  def resend_after
    return 0 unless created_at

    [ (created_at + RESEND_AFTER - Time.current).ceil, 0 ].max
  end
end
