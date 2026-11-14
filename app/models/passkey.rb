# One registered WebAuthn credential of a user. Verified by the webauthn gem
# against public_key; sign_count is the authenticator's counter (synced
# passkeys report 0 forever, which the gem accepts).
class Passkey < ApplicationRecord
  belongs_to :user

  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true
  validates :nickname, length: { maximum: User::NAME_MAX }

  def touch_usage!(sign_count)
    update!(sign_count: sign_count, last_used_at: Time.current)
  end
end
