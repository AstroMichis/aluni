require "rails_helper"

RSpec.describe "Menu sections 2 to 5", type: :request do
  let(:referer) { ->(path) { { "HTTP_REFERER" => "http://www.example.com#{path}" } } }

  describe "My crops" do
    it "shows what grows on each field, with its family and tip" do
      get "/en/menu/crops"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("crops.families.poaceae")).and include(I18n.t("fields.show.tips.stalk"))
      expect(response.body).to include(I18n.t("crops.tabs.rotation")).and include(I18n.t("crops.show.plant"))
    end

    it "shows the rotation with its checks, saves a plan and flags a repeat" do
      get "/en/menu/crops/rotation"
      expect(response.body).to include(I18n.t("crops.rotation.findings.same_family.label")).and include(I18n.t("crops.rotation.compare.title"))

      patch "/en/menu/crops/plan", params: { field: "creek", crop: "soybeans" }, headers: referer.call("/en/menu/crops/rotation")
      follow_redirect!
      expect(response.body).to include(I18n.t("preview.saved")).and include(I18n.t("crops.rotation.findings.monoculture.label"))
    end

    it "draws the calendar against the frost-free stretch" do
      get "/en/menu/crops/calendar"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("calendar__bar--frost-free").and include("calendar__bar--crop").and include(I18n.t("crops.calendar.missing"))
    end
  end

  describe "Weather" do
    it "shows the season's numbers, three charts with their data table and the forecast gap" do
      get "/es/menu/weather"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("854").and include('id="chart-temperature"').and include('id="chart-rain"').and include('id="chart-moisture"')
      expect(response.body).to include('data-controller="chart"').and include(I18n.t("weather.show.table.title", locale: :es))
      expect(response.body).to include(I18n.t("weather.show.forecast.title", locale: :es))
    end

    it "lists the season's alerts and turns kinds off" do
      get "/en/menu/weather/alerts"
      expect(response.body).to include(I18n.t("weather.alerts.kinds.dry_spell.label")).and include("timeline__item--heat")

      patch "/en/menu/weather/alerts", params: { alerts: [ "", "frost" ] }, headers: referer.call("/en/menu/weather/alerts")
      follow_redirect!
      expect(response.body).to include("timeline__item--heat timeline__item--off")
    end
  end

  describe "My team" do
    it "adds, edits and removes a member" do
      post "/en/menu/staff/members", params: { member: { name: "Rosa Díaz", role: "viewer", fields: [ "", "north" ] } }
      get "/en/menu/staff"
      expect(response.body).to include("Rosa Díaz").and include(I18n.t("staff.role_names.viewer"))

      patch "/en/menu/staff/members/m3", params: { member: { role: "worker", fields: [ "" ] } }
      get "/en/menu/staff"
      expect(response.body).to include(I18n.t("staff.show.no_fields"))

      delete "/en/menu/staff/members/m3"
      get "/en/menu/staff"
      expect(response.body).not_to include("Rosa Díaz")
    end

    it "adds a task, completes it and removes it" do
      post "/en/menu/staff/tasks", params: { task: { title: "Fix the fence", field: "creek", member: "m1", due: "2025-12-01" } }
      get "/en/menu/staff/tasks"
      expect(response.body).to include("Fix the fence").and include(I18n.t("staff.sample_tasks.scout"))

      patch "/en/menu/staff/tasks/t4", params: { done: "true" }
      get "/en/menu/staff/tasks"
      expect(response.body).to include(I18n.t("staff.tasks.groups.done", count: 2))

      delete "/en/menu/staff/tasks/t4"
      get "/en/menu/staff/tasks"
      expect(response.body).not_to include("Fix the fence")
    end

    it "shows what each role can do" do
      get "/en/menu/staff/roles"
      expect(response.body).to include(I18n.t("staff.capabilities.invite")).and include(I18n.t("staff.role_descriptions.viewer"))
    end
  end

  describe "Reports" do
    it "summarises the season, field by field" do
      get "/en/menu/reports"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("reports.show.fields_title")).and include('data-controller="print"').and include("meter-list__fill")
    end

    it "records a yield and compares fields growing the same crop" do
      patch "/en/menu/fields/creek/readings/yield", params: { value: "3.9" }
      get "/en/menu/reports/harvest"
      expect(response.body).to include("3.9 t/ha").and include(I18n.t("reports.harvest.benchmark.title"))
    end

    it "downloads the farm as CSV and JSON" do
      get "/en/menu/reports/download.csv"
      expect(response.media_type).to eq("text/csv")
      expect(response.body.lines.first.strip).to eq("subject,datum,state,value,source,scale,confidence")
      expect(response.body).to include("north,slope,auto,4.05,USGS 3DEP,parcel,high")

      get "/en/menu/reports/download.json"
      expect(JSON.parse(response.body)).to include("sample" => true, "plans" => { "north" => "soybeans" })
    end
  end

  it "links every menu option that has a screen" do
    get "/en/menu"
    %w[/en/menu/crops /en/menu/crops/rotation /en/menu/weather /en/menu/weather/alerts /en/menu/staff/tasks /en/menu/reports/harvest /en/menu/reports/export].each do |path|
      expect(response.body).to include(%(href="#{path}"))
    end
    expect(response.body).not_to include(I18n.t("pages.menu.soon"))
  end
end
