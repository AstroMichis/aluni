# frozen_string_literal: true

# Sample figures for the landing page preview: one real field near Ames, Iowa
# (farm_data_42.0_-93.75.json), as the app computes them: GDD by the 86/50
# method (Weather::Season#gdd), the comparator's totals (docs/proposal claims
# W7-W9, reproduced by ames_cross_check.rb), tar spot days by
# Weather::ScoutWindows and five seasons of the Cropland Data Layer.
# Labels and units live in the locale files; only the numbers sit here so
# both languages show the same field. spec/requests/pages_spec.rb holds them
# to the services.
module LandingHelper
  SAMPLE = {
    lat: "42.00", lon: "-93.75",
    om: "3.5", sand: 45, clay: 21, awc: "0.21", slope: "4.05", group: "B",
    frost_days: 86, gdd: 1702, heat_days: 8, rain_mm: 854,
    wetness: "0.49",
    scores: { current: 82, small_grain: 68, other_family: 60 },
    tar_spot_days: 38, dry_days: 6,
    crops: { 2021 => :corn, 2022 => :soybeans, 2023 => :corn, 2024 => :soybeans, 2025 => :corn }
  }.freeze

  # The five tour steps, in order; each has a partial in app/views/pages/home/.
  TOUR_STEPS = %i[location soil crops compare alerts].freeze

  def landing_sample = SAMPLE
  def tour_steps = TOUR_STEPS
end
