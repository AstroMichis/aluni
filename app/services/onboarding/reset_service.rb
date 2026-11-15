module Onboarding
  # Starts the chat over: empty transcript and proposal, first topic, active
  # again, counters at zero. Profile, farm, fields and crops are kept, and so
  # is an active block (a reset is not a way out of one).
  class ResetService < ApplicationService
    def initialize(user:)
      @user = user
    end

    def call
      session = step(EnsureProfileService.call(user: @user))[:session]
      session.update!(
        topic: Topics.first, status: :active, completed_at: nil, transcript: [], proposal: {},
        pending_message: nil, fallbacks_count: 0, turns_count: 0, strikes: 0, last_message_at: nil
      )
      Success(session)
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end
  end
end
