require "net/smtp"

module Auth
  # Sends a sign-in code to an email address. Never looks a user up: a known and
  # an unknown address get the same row, the same mail and the same answer, so
  # nothing here reveals who has an account. The mail goes out inline (a code
  # cannot wait for a queue) and respects the operator's mail switch.
  class RequestCodeService < ApplicationService
    EMAIL = URI::MailTo::EMAIL_REGEXP
    MAIL_ERRORS = [ Net::SMTPError, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError,
                    OpenSSL::SSL::SSLError, IOError, EOFError ].freeze

    def initialize(destination:, locale:, ip:, channel: "email", pending: {})
      @destination = destination
      @locale = locale.to_s
      @ip = ip
      @channel = channel.to_s
      @pending = pending
    end

    def call
      address = @destination.to_s.strip.downcase
      return Failure(code: :invalid_email) unless valid_address?(address)

      Platform::Switchboard.guard!(:mail)
      code = Codes.generate
      record = create_record(address, code)
      deliver(record, code)
      Rails.logger.info("[auth] sign-in code sent to #{masked(address)}")
      Success(sign_in_code: record, resend_after: SignInCode::RESEND_AFTER.to_i)
    rescue Platform::ServicePaused
      Failure(code: :unavailable)
    rescue *MAIL_ERRORS => e
      # SMTP errors echo the address; log the class only.
      Rails.logger.warn("[auth] sign-in code mail failed: #{e.class}")
      record&.destroy
      Failure(code: :unavailable)
    end

    private

    def valid_address?(address)
      address.present? && address.length <= User::NAME_MAX && address.match?(EMAIL)
    end

    def create_record(address, code)
      SignInCode.transaction do
        SignInCode.live.where(destination: address, channel: @channel).update_all(expires_at: Time.current)
        SignInCode.create!(
          channel: @channel, destination: address, code_digest: Codes.digest(address, code),
          expires_at: SignInCode::TTL.from_now, requester_ip: @ip, locale: locale, pending: sanitized_pending
        )
      end
    end

    def deliver(record, code)
      SignInMailer.code(sign_in_code: record, code: code, link: LinkToken.generate(record, code)).deliver_now
    end

    def locale
      I18n.available_locales.map(&:to_s).include?(@locale) ? @locale : I18n.default_locale.to_s
    end

    # Only what a sign-up may need later: a name, a locale, the finder's field.
    def sanitized_pending
      pending = (@pending || {}).to_h.transform_keys(&:to_s)
      clean = {}
      name = pending["display_name"].to_s.strip.first(User::NAME_MAX)
      clean["display_name"] = name if name.present?
      clean["locale"] = pending["locale"].to_s if I18n.available_locales.map(&:to_s).include?(pending["locale"].to_s)
      field = pending["field"]
      clean["field"] = field if field.is_a?(Hash) && field["latitude"].present?
      clean
    end

    def masked(address)
      local, domain = address.split("@", 2)
      "#{local.to_s.first(1)}***@#{domain}"
    end
  end
end
