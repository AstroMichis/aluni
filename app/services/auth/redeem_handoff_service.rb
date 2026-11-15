module Auth
  # Redeems a native hand-off token under a row lock: once, within two minutes.
  class RedeemHandoffService < ApplicationService
    def initialize(token:)
      @token = token
    end

    def call
      return Failure(code: :expired) if @token.blank?

      handoff = AuthHandoff.find_by(token_digest: AuthHandoff.digest(@token))
      return Failure(code: :expired) unless handoff

      AuthHandoff.transaction do
        handoff.lock!
        next Failure(code: :expired) unless handoff.usable?

        handoff.update!(used_at: Time.current)
        Success(user: handoff.user, sign_in_method: handoff.sign_in_method)
      end
    end
  end
end
