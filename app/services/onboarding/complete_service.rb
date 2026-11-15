module Onboarding
  # Closes the onboarding: the session becomes completed and the profile gets
  # its segment from SegmentClassifier. Idempotent; the transcript is kept
  # (encrypted) so a later chat has its context.
  class CompleteService < ApplicationService
    def initialize(user:)
      @user = user
    end

    def call
      rows = step EnsureProfileService.call(user: @user)
      segment = step(SegmentClassifier.call(user: @user))[:segment]
      ActiveRecord::Base.transaction do
        rows[:profile].update!(segment: segment)
        rows[:session].update!(status: :completed, completed_at: rows[:session].completed_at || Time.current)
      end
      Success(segment: segment)
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end
  end
end
