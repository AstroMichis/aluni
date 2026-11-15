# Who the farmer is and how they work. The onboarding chat fills it, the
# guidance reads it; no data source needs these answers, the advice does.
# Every enum starts at `unknown` and is prefixed because the values repeat.
class FarmerProfile < ApplicationRecord
  GOALS = %w[rotation crop_fit yield water_saving soil_health prices labour].freeze
  EQUIPMENT = %w[hand_tools draft_animals tractor planter sprayer harvester irrigation_system drone].freeze
  LIVESTOCK = %w[cattle goats sheep pigs poultry other].freeze
  MARKET_CHANNELS = %w[own_use local_market wholesale contract cooperative export].freeze
  PRACTICES = %w[organic certified_organic no_till regenerative].freeze
  NOTES_MAX = 2000

  belongs_to :user

  enum :role, { unknown: 0, owner: 10, manager: 20, worker: 30, advisor: 40 }, prefix: true
  enum :experience, { unknown: 0, first_season: 10, few_years: 20, experienced: 30 }, prefix: true
  enum :team, { unknown: 0, solo: 10, family: 20, small_team: 30, crew: 40 }, prefix: true
  enum :units, { metric: 0, imperial: 10 }, prefix: true
  enum :land_tenure, { unknown: 0, own: 10, rent: 20, mixed: 30 }, prefix: true
  enum :budget_level, { unknown: 0, low: 10, high: 20 }, prefix: true
  enum :risk_tolerance, { unknown: 0, cautious: 10, balanced: 20, bold: 30 }, prefix: true
  enum :segment, { unknown: 0, smallholder_subsistence: 10, small_commercial: 20, mid_mechanized: 30, large_commercial: 40 }, prefix: true

  validates :team_size, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :goals, json_allowlist: { values: GOALS }
  validates :equipment, json_allowlist: { values: EQUIPMENT }
  validates :livestock, json_allowlist: { values: LIVESTOCK }
  validates :market_channels, json_allowlist: { values: MARKET_CHANNELS }
  validates :practices, json_allowlist: { values: PRACTICES }
  validates :notes, length: { maximum: NOTES_MAX }, allow_nil: true
end
