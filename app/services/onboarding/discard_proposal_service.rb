module Onboarding
  # "Not now" on the confirm card: drops the staged proposal, nothing else.
  class DiscardProposalService < ApplicationService
    def initialize(user:)
      @user = user
    end

    def call
      session = step(EnsureProfileService.call(user: @user))[:session]
      session.update!(proposal: {})
      Success(session)
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end
  end
end
