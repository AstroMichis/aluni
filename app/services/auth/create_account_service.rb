module Auth
  # Creates the account behind a code that was just proven: the name (typed now
  # or parked with the request), the verified address, the locale, and the
  # finder's field when one travelled with the sign-up.
  class CreateAccountService < ApplicationService
    def initialize(sign_in_code:, display_name:, ip:)
      @sign_in_code = sign_in_code
      @display_name = display_name
      @ip = ip
    end

    def call
      record = @sign_in_code
      return Failure(code: :expired) unless usable?(record)
      return Failure(code: :signups_closed) unless Platform::Features.signups_enabled?

      existing = User.find_by(email_address: record.destination)
      return Success(user: existing, created: false) if existing

      name = (@display_name.presence || record.pending["display_name"]).to_s.strip.first(User::NAME_MAX)
      return Failure(code: :name_required) if name.blank?

      user = User.transaction do
        User.create!(display_name: name, email_address: record.destination, locale: locale(record), email_verified_at: Time.current).tap do |u|
          save_field(u, record.pending["field"])
          record.update!(used_at: Time.current)
        end
      end
      Success(user: user, created: true)
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end

    private

    def usable?(record)
      record&.verified? && !record.used? && record.verified_at > SignInCode::TTL.ago
    end

    def locale(record)
      candidate = record.pending["locale"].presence || record.locale
      I18n.available_locales.map(&:to_s).include?(candidate) ? candidate : I18n.default_locale.to_s
    end

    def save_field(user, field)
      return unless field.is_a?(Hash)

      case Fields::SaveSetupService.call(user: user, attributes: field)
      in Result::Failure(error) then Rails.logger.warn("[auth] field not saved with the new account: #{error.inspect}")
      else nil
      end
    end
  end
end
