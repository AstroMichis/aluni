# A one-use token minted when a social sign-in started from a native shell
# finishes in the system browser: the shell opens /auth/handoff?token= in its
# web view and the session starts there. Stored as a digest, two minutes.
class AuthHandoff < ApplicationRecord
  TTL = 2.minutes

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :sign_in_method, presence: true
  validates :expires_at, presence: true

  def self.digest(token) = OpenSSL::Digest::SHA256.hexdigest(token.to_s)

  def usable? = used_at.nil? && expires_at.future?
end
