module Onboarding
  # Gives a user the rows the onboarding chat writes into: a profile, one farm
  # with one field, and the session. Idempotent, one transaction.
  class EnsureProfileService < ApplicationService
    def initialize(user:)
      @user = user
    end

    def call
      rows = ActiveRecord::Base.transaction do
        profile = @user.farmer_profile || @user.create_farmer_profile!
        farm = @user.farms.first || @user.farms.create!
        field = farm.fields.first || farm.fields.create!(position: 0)
        session = @user.onboarding_session || @user.create_onboarding_session!(language: @user.locale)
        { profile: profile, farm: farm, field: field, session: session }
      end
      Success(rows)
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end
  end
end
