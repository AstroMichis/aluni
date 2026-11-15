module Auth
  # Checks a typed code against its row under a lock: attempts count before
  # the comparison, a consumed or expired row never matches again, and only a
  # proven code looks for the account behind the address.
  class VerifyCodeService < ApplicationService
    def initialize(sign_in_code:, code:, ip:)
      @sign_in_code = sign_in_code
      @code = code
      @ip = ip
    end

    def call
      record = @sign_in_code
      return Failure(code: :expired) unless record

      case check(record)
      when :expired then Failure(code: :expired)
      when :wrong
        record.exhausted? ? Failure(code: :expired) : Failure(code: :wrong, attempts_left: SignInCode::MAX_ATTEMPTS - record.attempts)
      else
        resolve(record)
      end
    end

    private

    def check(record)
      SignInCode.transaction do
        record.lock!
        next :expired unless record.live? && !record.exhausted?

        record.increment!(:attempts)
        next :wrong unless Codes.match?(record, @code)

        record.update!(consumed_at: Time.current, verified_at: Time.current)
        :ok
      end
    end

    def resolve(record)
      user = User.find_by(email_address: record.destination)
      if user
        verify_email(user)
        Success(user: user, sign_in_code: record)
      elsif Platform::Features.signups_enabled?
        Success(user: nil, sign_in_code: record)
      else
        Failure(code: :signups_closed)
      end
    end

    # A code proves the address; an address typed at a passkey sign-up never was.
    def verify_email(user)
      return if user.email_verified_at.present?

      user.update_column(:email_verified_at, Time.current)
      Rails.logger.info("[auth] code sign-in verified a previously unverified address for user #{user.id}")
    end
  end
end
