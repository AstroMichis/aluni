# The state of one person's onboarding chat: the current topic, the encrypted
# transcript (so a refresh or a day away resumes), the proposal waiting for the
# confirm card, and the abuse counters. One row per user; topics come from
# config/onboarding/topics.yml (Onboarding::Topics), not from here.
class OnboardingSession < ApplicationRecord
  belongs_to :user

  enum :status, { active: 0, completed: 10 }

  serialize :transcript, coder: JSON
  encrypts :transcript
  encrypts :pending_message

  validates :topic, presence: true
  validates :language, inclusion: { in: ->(_session) { I18n.available_locales.map(&:to_s) } }, allow_nil: true
  validates :fallbacks_count, :turns_count, :strikes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Always an array; assign a new array to change it (`session.transcript += [turn]`).
  def transcript = super || []

  def blocked? = blocked_until.present? && blocked_until.future?
end
