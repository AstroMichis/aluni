# frozen_string_literal: true

# A signed-in farmer with a finished onboarding, one located US field and the
# observations the data sources would store for it (values from the samples
# captured in docs/data_sources/), plus a browser sign-in for system specs.
module FarmFixtures
  def power_payload(year: Date.current.year)
    days = (Date.new(year, 1, 1)..Date.new(year, 10, 31)).to_a
    daily = { "T2M" => {}, "T2M_MIN" => {}, "T2M_MAX" => {}, "PRECTOTCORR" => {}, "GWETROOT" => {} }
    days.each_with_index do |day, i|
      key = day.strftime("%Y%m%d")
      t = 12 + (14 * Math.sin((i - 100) * Math::PI / 180))
      daily["T2M"][key] = t.round(2)
      daily["T2M_MIN"][key] = (t - 7).round(2)
      daily["T2M_MAX"][key] = (t + 5 + (i == 200 ? 15 : 0)).round(2)
      daily["PRECTOTCORR"][key] = (i % 9).zero? ? (i == 180 ? 40.0 : 12.0) : 0.0
      daily["GWETROOT"][key] = 0.45
    end
    { "from" => days.first.iso8601, "to" => days.last.iso8601, "daily" => daily, "elevation" => 491.1, "climatology" => climatology_normals }
  end

  # The captured climatology sample plus synthetic humidity, wind, radiation,
  # mean temperature and rain for every month (test data, for the FAO-56 math).
  def climatology_normals
    captured = JSON.parse(data_source_fixture("power_climatology.json")).dig("properties", "parameter")
    months = Weather::Season::MONTHS
    t = [ -4, -2, 4, 11, 17, 22, 25, 24, 19, 11, 4, -2 ]
    rain = [ 0.6, 0.8, 1.6, 2.4, 3.9, 3.6, 2.5, 3.0, 2.4, 1.8, 1.1, 0.8 ]
    sun = [ 8, 11, 15, 19, 22, 24, 24, 21, 17, 12, 8, 7 ]
    captured.merge(
      "T2M" => months.zip(t).to_h.merge("ANN" => 10.86), "PRECTOTCORR" => months.zip(rain).to_h.merge("ANN" => 1.98),
      "RH2M" => months.to_h { |m| [ m, 70.0 ] }, "WS2M" => months.to_h { |m| [ m, 4.5 ] }, "ALLSKY_SFC_SW_DWN" => months.zip(sun).to_h
    )
  end

  def create_farm_for(user, us: true)
    create(:onboarding_session, :completed, user: user)
    create(:farmer_profile, user: user, budget_level: :high, segment: :mid_mechanized, goals: %w[rotation soil_health], equipment: %w[tractor])
    farm = create(:farm, user: user, name: "Finca Ana")
    field = create(:field, farm: farm, name: "North field", latitude: 40.95, longitude: -97.50, area: 32.4)
    create(:field_crop, field: field, crop_name: "Corn", scientific_name: "Zea mays", season_year: Date.current.year)
    create(:field_crop, field: field, crop_name: "Soybeans", scientific_name: "Glycine max", season_year: Date.current.year - 1, planting_month: 5, harvest_month: 9)
    observe(field, us: us)
    field
  end

  def observe(field, us: true)
    create(:field_observation, field: field, source: "nasa_power", payload: power_payload)
    create(:field_observation, field: field, source: "gaez", payload: {
      "input_level" => "High", "water_supply" => "Rainfed",
      "crops" => { "Maize" => { "suitability" => 8700.0, "yield" => 6867.0, "yield_units" => "kg DW/ha" },
                   "Soybean" => { "suitability" => 7600.0, "yield" => 2900.0, "yield_units" => "kg DW/ha" },
                   "Alfalfa" => { "suitability" => 6100.0, "yield" => 1200.0, "yield_units" => "10kg DW/ha" } } })
    if us
      create(:field_observation, field: field, source: "fcc", payload: { "state_code" => "NE", "state" => "Nebraska" })
      create(:field_observation, field: field, source: "ssurgo", payload: {
        "muname" => "Hastings silt loam, 0 to 1 percent slopes", "compname" => "Hastings", "drainagecl" => "Well drained",
        "om_r" => 3.0, "sandtotal_r" => 13.0, "claytotal_r" => 24.0, "awc_r" => 0.23, "ph1to1h2o_r" => 5.8,
        "kwfact" => 0.32, "slopelenusle_r" => 61.0, "tfact" => 5.0, "hydgrp" => "B" })
      create(:field_observation, field: field, source: "usgs_elevation", payload: { "elevation" => 497.3, "slope" => 1.2 })
      create(:field_observation, field: field, source: "cdl", payload: { "years" => { (Date.current.year - 2).to_s => "Corn", (Date.current.year - 3).to_s => "Soybeans" } })
    else
      %w[ssurgo usgs_elevation cdl].each { |s| create(:field_observation, field: field, source: s, status: :out_of_coverage) }
      create(:field_observation, field: field, source: "fcc", status: :empty)
    end
  end

  # Cuprite: the signed session cookie Authentication reads.
  def browser_sign_in(user)
    session = user.sessions.create!(user_agent: "Cuprite", ip_address: "127.0.0.1")
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_id] = session.id
    visit root_path(locale: "en")
    page.driver.set_cookie("session_id", jar[:session_id])
  end
end

RSpec.configure { |config| config.include FarmFixtures }
