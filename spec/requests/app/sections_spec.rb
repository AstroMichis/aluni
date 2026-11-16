require "rails_helper"

RSpec.describe "Menu sections on the farmer's own farm", type: :request do
  let(:user) { create(:user, display_name: "Ana") }
  let!(:field) { create_farm_for(user) }

  before { sign_in_as(user) }

  it "shows the menu dial once the onboarding is complete, with every option linked" do
    get app_root_path(locale: "en"), headers: native_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="radial-menu"').and include(I18n.t("app.home.show.greeting", name: "Ana"))
    # A farm with one field opens it directly from My fields.
    %W[/en/app/fields/#{field.id} /en/app/fields/new /en/app/crops /en/app/weather /en/app/team /en/app/reports/harvest].each do |path|
      expect(response.body).to include(%(href="#{path}"))
    end
    expect(response.body).not_to include(I18n.t("app.home.show.soon"))
    expect(response.body).to include(I18n.t("app.home.show.plan.title")).and include(%(href="/en/app/fields/#{field.id}/rotation"))
  end

  it "shows the field from space with its bare-soil window on the field and on the plan" do
    start = Date.current.beginning_of_month << 5
    months = [ 0.1, 0.12, 0.2, 0.6, 0.7, nil ].each_with_index.map do |v, i|
      { "month" => (start >> i).strftime("%Y-%m"), "ndvi" => v, "mission" => v && "landsat", "scene" => v && "LC09_#{i}",
        "date" => v && (start >> i).iso8601 }
    end
    create(:field_observation, field: field, source: "vegetation", status: :ok, payload: { "months" => months })

    [ app_field_path(field, locale: "en"), app_field_rotation_path(field, locale: "en") ].each do |path|
      get path, headers: native_headers
      expect(response.body).to include(I18n.t("app.vegetation.title")).and include(I18n.t("app.vegetation.covers.bare"))
      expect(response.body).to include("months in a row").and include("vegetation__month--unknown")
      expect(response.body).to include('data-controller="ndvi-map"').and include("LC09_4") # the latest clear scene on the map
    end
  end

  it "opens the dial on the section a screen came back from, and every screen can jump to any section" do
    get app_root_path(locale: "en", section: "weather"), headers: native_headers
    expect(response.body).to include(%(aria-valuetext="#{I18n.t('app.home.show.sections.weather.title')}"))
    expect(response.body).to include(%(class="dial__hub" href="/en/app/weather"))

    get app_weather_path(locale: "en"), headers: native_headers
    expect(response.body).to include(%(href="/en/app?section=weather"))
    expect(response.body).to include('class="section-switch"').and include(%(href="/en/app/team"))

    get new_app_field_path(locale: "en"), headers: native_headers
    expect(response.body).not_to include('class="section-switch"')
  end

  it "lists the fields and opens one with the farmer's answers and the sources' values" do
    get app_fields_path(locale: "en"), headers: native_headers
    expect(response.body).to include("North field").and include("Corn")

    get app_field_path(field, locale: "en"), headers: native_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("gibs.earthdata.nasa.gov").and match(%r{<turbo-frame[^>]*id="workspace"[^>]*target="_top"})
    expect(response.body).to include(%(href="/en/app/fields/#{field.id}/edit")).and include(I18n.t("app.fields.show.suggestions.confirm_all"))

    get app_field_path(field, locale: "en", tab: "data"), headers: native_headers
    expect(response.body).to include("Hastings silt loam").and include("USGS 3DEP")
    expect(response.body).to include(I18n.t("app.fields.actions.proposal", value: I18n.t("onboarding.values.texture.medium")))
    expect(response.body).to include(%(href="/en/app/fields/#{field.id}/edit?focus=soil_texture#field-soil_texture"))
    expect(response.body).to include(I18n.t("app.fields.data_sources.title")).and include(I18n.t("app.fields.data_sources.states.ok"))
  end

  it "edits a whole field in one form, with the source suggestions beside their fields" do
    get edit_app_field_path(field, locale: "en"), headers: native_headers
    expect(response.body).to include('name="values[irrigation]"').and include('name="confirm[]" value="soil_texture"')
    expect(response.body).to include(I18n.t("app.fields.edit.use_suggestion", source: "SSURGO", value: I18n.t("onboarding.values.texture.medium")))

    patch app_field_path(field, locale: "en"), headers: native_headers,
          params: { values: { irrigation: "drip", soil_depth: "deep" }, confirm: %w[soil_texture] }
    expect(response).to redirect_to(app_field_path(field, locale: "en", tab: "data"))
    expect(field.reload).to have_attributes(irrigation: "drip", soil: include("depth" => "deep", "texture" => "medium"))
  end

  it "confirms every suggestion at once" do
    post confirm_app_field_path(field, locale: "en"), headers: native_headers
    expect(field.reload.soil).to include("texture" => "medium", "drainage" => "well", "ph" => 5.8)
    expect(field.field_crops.where(source: "cdl").count).to eq(2)
  end

  it "adds a field from the form and asks the sources about it" do
    expect {
      post app_fields_path(locale: "en"), headers: native_headers, params: {
        field: { name: "Road field", latitude: "9.93", longitude: "-84.08", area: "3", area_unit: "hectares", irrigation: "drip",
                 crop: "Frijol", history: { (Date.current.year - 1).to_s => "Maíz" } } }
    }.to have_enqueued_job(Fields::FetchObservationsJob)

    created = user.farms.first.fields.find_by(name: "Road field")
    expect(response).to redirect_to(app_field_path(created, locale: "en"))
    expect(created.field_crops.count).to eq(2)
  end

  it "compares rotations and turns a strategy into next season's plan" do
    allow(Gemini::Client).to receive(:configured?).and_return(false)
    get app_field_rotation_path(field, locale: "en"), headers: native_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("app.rotations.strategies.current.title")).and include(I18n.t("app.rotations.strategies.small_grain.title"))
    expect(response.body).to include(I18n.t("app.rotations.gaps.market")).and include("turbo-frame")
    expect(response.body).to include(I18n.t("app.timeline.title")).and include("timeline__cell--crop")

    get why_app_field_rotation_path(field, strategy: "small_grain", locale: "en"), headers: native_headers
    expect(response.body).to include('id="why-small_grain"') # rule-based text while Gemini is unconfigured in test

    get app_field_rotation_path(field, scenario: "warm2", locale: "en"), headers: native_headers
    expect(response.body).to include(ERB::Util.h(I18n.t("app.scenario.active", name: "+2 °C"))).and include("scenario=warm2")

    patch plan_app_crops_path(locale: "en"), params: { field: field.id, crop: "glycine-max" }, headers: native_headers
    expect(field.field_crops.find_by(season_year: Date.current.year + 1).scientific_name).to eq("Glycine max")
  end

  it "asks the sources again on refresh" do
    expect { post refresh_app_field_path(field, locale: "en"), headers: native_headers }.to have_enqueued_job(Fields::FetchObservationsJob).with(field.id)
  end

  it "keeps the answers and says why when a new field is sent with a wrong pin" do
    expect {
      post app_fields_path(locale: "en"), headers: native_headers,
                                          params: { field: { name: "Parcela", latitude: "-33.59", longitude: "-708476706", crop: "Maize" } }
    }.not_to change(Field, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include(ERB::Util.h(I18n.t("app.fields.create.invalid_location"))).and include("toast--error")
    expect(response.body).to include('value="Parcela"').and include('value="-708476706"').and include('value="Maize"')
  end

  it "shows the farm profile, the team and the sources" do
    get app_farm_path(locale: "en"), headers: native_headers
    expect(response.body).to include("Finca Ana").and include(I18n.t("onboarding.values.segment.mid_mechanized"))

    get edit_app_farm_path(locale: "en"), headers: native_headers
    expect(response.body).to include('name="values[goals][]"')
    patch app_farm_path(locale: "en"), headers: native_headers, params: { values: { budget_level: "low", goals: [ "", "yield" ] } }
    expect(user.farmer_profile.reload).to have_attributes(budget_level: "low", goals: %w[yield])

    get app_team_path(locale: "en"), headers: native_headers
    expect(response.body).to include(I18n.t("onboarding.values.team.family")).and include(I18n.t("onboarding.values.equipment.tractor"))

    get sources_app_fields_path(locale: "en"), headers: native_headers
    expect(response.body).to include("NASA POWER").and include("NASADEM (SRTM)")
  end

  it "shows the crops with their GAEZ potential, the rotation and the calendar" do
    get app_crops_path(locale: "en"), headers: native_headers
    expect(response.body).to include(I18n.t("app.crops.suitability.very_high")).and include(I18n.t("app.crops.attainable", value: "6.9"))

    get rotation_app_crops_path(locale: "en"), headers: native_headers
    expect(response.body).to include(I18n.t("app.crops.rotation.potential_title")).and include(I18n.t("app.crops.rotation.cdl_waiting", count: 2))

    patch plan_app_crops_path(locale: "en"), params: { field: field.id, crop: "medicago-sativa" }, headers: native_headers
    expect(field.field_crops.find_by(season_year: Date.current.year + 1).scientific_name).to eq("Medicago sativa")

    get calendar_app_crops_path(locale: "en"), headers: native_headers
    expect(response.body).to include("calendar__bar--frost-free")
  end

  it "shows the weather at the pin and keeps the alert choices in the profile" do
    get app_weather_path(locale: "en"), headers: native_headers
    expect(response.body).to include('id="chart-temperature"').and include(I18n.t("app.weather.show.table.rain_normal"))

    patch alerts_app_weather_path(locale: "en"), params: { alerts: [ "", "frost" ] }, headers: native_headers
    expect(user.farmer_profile.reload.notification_preferences["weather"]).to eq(%w[frost])
  end

  it "loads the next seven days lazily, with the day's alerts" do
    get app_weather_path(locale: "en"), headers: native_headers
    expect(response.body).to include('id="forecast"').and include("src=\"#{forecast_app_weather_path(field: field.id, locale: "en")}")

    start = Time.current.utc.beginning_of_day
    series = { "t_2m:C" => Array.new(48) { |i| [ start + i.hours, i < 24 ? 12.0 : -2.0 ] },
               "precip_1h:mm" => Array.new(48) { |i| [ start + i.hours, 0.0 ] } }
    client = instance_double(Meteomatics::Client, forecast: series, last_error: nil)
    allow(Meteomatics::Client).to receive_messages(configured?: true, new: client)

    get forecast_app_weather_path(locale: "en"), headers: native_headers
    expect(response.body).to include('<turbo-frame id="forecast">').and include("frost possible")
  end

  it "lists the recent weather alerts, sent or shown here only" do
    NotificationDelivery.create!(recipient: user, purpose: "weather_alert", status: :skipped,
                                 idempotency_key: Weather::DailyAlertsJob.key(field.id, Date.current, "frost"))

    get alerts_app_weather_path(locale: "en"), headers: native_headers

    expect(response.body).to include(I18n.t("app.weather.alerts.recent.title")).and include(I18n.t("app.weather.alerts.recent.here_only"))
  end

  it "explains why there is no weather yet for a field without a pin" do
    bare = create(:field, :unlocated, farm: field.farm)
    get app_weather_path(field: bare.id, locale: "en"), headers: native_headers
    expect(response.body).to include(I18n.t("app.weather.no_season.needs_pin"))
  end

  it "reports the season and the attainable harvest, and exports the farm" do
    get app_reports_path(locale: "en"), headers: native_headers
    expect(response.body).to include(I18n.t("app.reports.show.fields_title")).and include("Corn")

    get harvest_app_reports_path(locale: "en"), headers: native_headers
    expect(response.body).to include(I18n.t("app.crops.attainable", value: "6.9"))

    get download_app_reports_path(format: :csv, locale: "en"), headers: native_headers
    expect(response.body).to include("#{field.id},slope,auto,1.2,USGS 3DEP,parcel,high")
    get download_app_reports_path(format: :json, locale: "en"), headers: native_headers
    expect(JSON.parse(response.body)["fields"].first["sources"]).to include("nasa_power" => include("status" => "ok"))
  end

  it "keeps another farmer's field out of reach" do
    other = create(:field)
    get app_field_path(other, locale: "en"), headers: native_headers
    expect(response).to have_http_status(:not_found)
  end

  it "has no public menu any more" do
    expect { Rails.application.routes.recognize_path("/en/menu") }.to raise_error(ActionController::RoutingError)
  end
end
