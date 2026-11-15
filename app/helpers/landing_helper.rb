# frozen_string_literal: true

# Sample figures for the landing page preview: one real field near Ames, Iowa
# (farm_data_42.0_-93.75.json). Labels and units live in the locale files;
# only the numbers sit here so both languages show the same field.
module LandingHelper
  SAMPLE = {
    lat: "42.00", lon: "-93.75",
    om: "3.5", sand: 45, clay: 21, awc: "0.21", slope: "4.05", group: "B",
    frost_days: 86, gdd: 1915, heat_days: 8, rain_mm: 854,
    wetness: "0.49", wetness_low: "0.42",
    crops: { 2020 => :soybeans, 2021 => :corn, 2022 => :soybeans, 2023 => :corn, 2024 => :soybeans, 2025 => :corn }
  }.freeze

  # The five tour steps, in order; each has a partial in app/views/pages/home/.
  TOUR_STEPS = %i[location soil crops compare alerts].freeze

  def landing_sample = SAMPLE
  def tour_steps = TOUR_STEPS

  # Where "start with your own field" leads: the app for a signed-in visitor,
  # otherwise account creation (or sign-in while sign-ups are closed).
  def landing_start_path
    return app_root_path if authenticated?

    signups_enabled? ? sign_up_path : sign_in_path
  end
end
