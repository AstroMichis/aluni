module Auth
  # Removes a linked provider from the account page, unless it is the last way
  # in: another provider, a passkey or a verified email (for a code) must remain.
  class DisconnectIdentityService < ApplicationService
    def initialize(user:, identity:)
      @user = user
      @identity = identity
    end

    def call
      return Failure(code: :not_found) unless @identity && @identity.user_id == @user.id
      return Failure(code: :last_way_in) unless other_way_in?

      @identity.destroy!
      Success(identity: @identity)
    end

    private

    def other_way_in?
      @user.identities.where.not(id: @identity.id).exists? ||
        @user.passkeys.exists? ||
        @user.email_verified_at.present?
    end
  end
end
