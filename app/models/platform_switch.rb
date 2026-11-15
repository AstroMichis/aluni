# A pause flag for one outside service. Read through Platform::Switchboard,
# which caches every row for 15 seconds; written by Platform::ToggleService.
class PlatformSwitch < ApplicationRecord
  SERVICES = %w[jobs cron gemini mail push meteomatics planetary_computer].freeze

  validates :service, inclusion: { in: SERVICES }, uniqueness: true

  scope :paused, -> { where(paused: true) }
end
