module Auth
  # The one-tap link in the code mail: a signed, expiring token carrying the row
  # id and the code. Reading it never signs anyone in by itself; the controller
  # still runs VerifyCodeService (attempts, expiry, single use).
  module LinkToken
    PURPOSE = :sign_in_link

    module_function

    def generate(sign_in_code, code)
      verifier.generate({ "id" => sign_in_code.id, "code" => code }, purpose: PURPOSE, expires_in: SignInCode::TTL)
    end

    # { "id" => Integer, "code" => String } or nil when tampered with or expired.
    def read(token)
      payload = verifier.verified(token.to_s, purpose: PURPOSE)
      payload.is_a?(Hash) && payload["id"].present? && payload["code"].present? ? payload : nil
    end

    def verifier = Rails.application.message_verifier(PURPOSE)
  end
end
