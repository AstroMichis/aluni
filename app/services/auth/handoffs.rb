module Auth
  # One-use tokens for the native shells (AuthHandoff): a social sign-in that
  # started in a shell finishes in the system browser, which mints one; the
  # shell's web view redeems it at /auth/handoff (RedeemHandoffService).
  module Handoffs
    module_function

    def mint(user:, sign_in_method:)
      token = SecureRandom.urlsafe_base64(32)
      user.auth_handoffs.create!(token_digest: AuthHandoff.digest(token), sign_in_method: sign_in_method,
                                 expires_at: AuthHandoff::TTL.from_now)
      token
    end
  end
end
