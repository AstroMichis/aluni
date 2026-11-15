module Auth
  # A provider (Google, Apple, Microsoft) has proven who the person is; this
  # finds or creates the account behind that proof, or links the provider to
  # the person already signed in (current_user, from the passkeys page).
  #
  #   1. The provider account is already linked: that user.
  #   2. Connecting from the account page: link it to current_user.
  #   3. A verified address that belongs to an account: link and sign in
  #      ("proof wins", the same rule as the emailed code).
  #   4. An unverified address that belongs to an account: refuse, never link.
  #   5. Otherwise a new account, when sign-ups are open.
  #
  # Google and Apple vouch for their addresses; Microsoft's are never trusted
  # for linking. No provider tokens are kept.
  class SocialSignInService < ApplicationService
    def initialize(auth:, pending: {}, current_user: nil)
      @auth = auth
      @pending = pending || {}
      @current_user = current_user
    end

    def call
      profile = step(normalize(@auth))
      identity = Identity.find_by(provider: profile[:provider], uid: profile[:uid])

      return link(identity, profile) if @current_user
      return returning(identity, profile) if identity

      by_email = profile[:email] && User.find_by(email_address: profile[:email])
      if by_email
        return Failure(code: :email_conflict) unless profile[:email_verified]
        return Failure(code: :email_conflict) if by_email.identities.exists?(provider: profile[:provider])

        attach(by_email, profile)
        verify_email(by_email)
        Rails.logger.info("[auth] #{profile[:provider]} linked by verified email to user #{by_email.id}")
        return Success(user: by_email, created: false)
      end

      create_account(profile)
    rescue ActiveRecord::RecordNotUnique
      Failure(code: :already_linked)
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end

    private

    def normalize(auth)
      provider = auth&.provider.to_s
      uid = auth&.uid.to_s
      return Failure(code: :provider_failed) unless Identity::PROVIDERS.include?(provider) && uid.present?

      info = auth.info || {}
      email = info.email.to_s.strip.downcase.presence
      email = nil if email && (email.length > User::NAME_MAX || !email.match?(URI::MailTo::EMAIL_REGEXP))
      Success(
        provider: provider,
        uid: uid,
        email: email,
        email_verified: email.present? && verified?(provider, info),
        name: name_from(info)
      )
    end

    def verified?(provider, info)
      case provider
      when "google_oauth2", "apple" then [ true, "true" ].include?(info.email_verified)
      else false
      end
    end

    def name_from(info)
      full = info.name.to_s.squish.presence ||
             [ info.first_name, info.last_name ].compact.join(" ").squish.presence ||
             info.nickname.to_s.squish.presence
      full&.first(User::NAME_MAX)
    end

    def returning(identity, profile)
      identity.update!(last_used_at: Time.current, email: profile[:email] || identity.email,
                       email_verified: profile[:email_verified] || identity.email_verified)
      Success(user: identity.user, created: false)
    end

    def link(identity, profile)
      if identity
        return Failure(code: :already_linked) unless identity.user_id == @current_user.id

        return Success(user: @current_user, created: false, linked: true)
      end
      return Failure(code: :already_linked) if @current_user.identities.exists?(provider: profile[:provider])

      attach(@current_user, profile)
      Success(user: @current_user, created: false, linked: true)
    end

    def create_account(profile)
      return Failure(code: :signups_closed) unless Platform::Features.signups_enabled?

      name = @pending["display_name"].to_s.squish.first(User::NAME_MAX).presence ||
             profile[:name] ||
             profile[:email]&.split("@")&.first&.first(User::NAME_MAX)
      return Failure(code: :name_required) if name.blank?

      verified = profile[:email_verified]
      user = User.transaction do
        User.create!(
          display_name: name,
          email_address: (profile[:email] if verified),
          email_verified_at: (Time.current if verified),
          locale: locale
        ).tap do |created|
          attach(created, profile)
          save_field(created, @pending["field"])
        end
      end
      Success(user: user, created: true)
    end

    def attach(user, profile)
      user.identities.create!(provider: profile[:provider], uid: profile[:uid], email: profile[:email],
                              email_verified: profile[:email_verified], name: profile[:name], last_used_at: Time.current)
    end

    def verify_email(user)
      user.update_column(:email_verified_at, Time.current) if user.email_verified_at.nil?
    end

    def locale
      candidate = @pending["locale"].to_s
      I18n.available_locales.map(&:to_s).include?(candidate) ? candidate : I18n.default_locale.to_s
    end

    def save_field(user, field)
      return unless field.is_a?(Hash) && field.any?

      case Fields::SaveSetupService.call(user: user, attributes: field)
      in Result::Failure(error) then Rails.logger.warn("[auth] field not saved with the new account: #{error.inspect}")
      else nil
      end
    end
  end
end
