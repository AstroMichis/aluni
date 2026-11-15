require "rails_helper"

RSpec.describe "My fields", type: :request do
  let(:profile) { Fields::Profile.current }

  def add_field(answers = {})
    post "/en/menu/fields", params: { answers: { location: "42.00, -93.75", name: "Road field", boundary: "drawn", area: "12.5", current_crop: "wheat",
                                                 water_access: "rainfed", goals: %w[soil income] }.merge(answers), confirmed: %w[soil_type] }
  end

  describe "the sample farm" do
    it "lists its fields with their progress and says it is a sample" do
      get "/en/menu/fields"

      expect(response).to have_http_status(:ok)
      %w[north creek home].each { |key| expect(response.body).to include(I18n.t("fields.sample.#{key}")) }
      expect(response.body).to include(I18n.t("fields.preview.sample_title")).and include(I18n.t("fields.tabs.farm"))
      expect(response.body).to include("meter__fill").and include('href="/en/menu/fields/new"')
    end

    it "shows the farm page with the profile, the to-do list and the farm data" do
      get "/en/menu/fields/farm"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("fields.classification.size.large")).and include("NASA POWER")
      expect(response.body).to include(I18n.t("fields.todo.title")).and include('data-controller="section-nav"')
    end

    it "shows a field with its plants, history, to-do list and in-place actions" do
      get "/en/menu/fields/north"

      expect(response).to have_http_status(:ok)
      expect(response.body.scan('class="plot__plant"').size).to eq(12)
      expect(response.body).to include("Clarion loam").and include("USGS 3DEP").and include(I18n.t("fields.show.tips.stalk"))
      expect(response.body).to include('href="#reading-north-soil_texture"').and include(I18n.t("fields.actions.confirm"))
      expect(response.body).to include('name="turbo-refresh-method" content="morph"')
    end

    it "answers 404 for an unknown field or datum" do
      get "/en/menu/fields/nowhere"
      expect(response).to have_http_status(:not_found)

      patch "/en/menu/fields/north/readings/nothing", params: { value: "x" }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "changing data in place" do
    it "confirms an inferred value and keeps it in the session" do
      patch "/en/menu/fields/north/readings/soil_texture", params: { confirm: 1 }, headers: { "HTTP_REFERER" => "http://www.example.com/en/menu/fields/north" }

      expect(response).to redirect_to("http://www.example.com/en/menu/fields/north")
      follow_redirect!
      expect(response.body).to include(I18n.t("preview.saved"))
      expect(response.body).not_to include('href="#reading-north-soil_texture"')
      expect(response.body).to include(I18n.t("fields.preview.sample_title"))
    end

    it "plants a crop on the empty field" do
      patch "/en/menu/fields/home/readings/current_crop", params: { value: "oats" }
      get "/en/menu/fields/home"

      expect(response.body.scan('class="plot__plant"').size).to eq(12)
      expect(response.body).to include("plot--grain").and include(I18n.t("fields.show.tips.grain"))
    end

    it "keeps a correction as the person's value and refuses values that do not fit" do
      patch "/en/menu/fields/north/readings/slope", params: { value: "Steeper by the creek" }
      get "/en/menu/fields/north"
      expect(response.body).to include("Steeper by the creek").and include(I18n.t("fields.origin.corrected"))

      patch "/en/menu/fields/farm/readings/water_access", params: { value: "a lot" }
      follow_redirect!
      expect(response.body).to include(I18n.t("preview.invalid"))
    end
  end

  describe "adding a field" do
    it "renders every step of the conversation in Spanish" do
      get "/es/menu/fields/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="onboarding"').and include('action="/es/menu/fields"')
      profile.steps.each do |step|
        expect(response.body).to include(CGI.escapeHTML(I18n.t("fields.new.steps.#{step.key}.question", locale: :es)))
      end
    end

    it "starts the person's own farm, at the measured point, and opens the new field" do
      add_field

      expect(response).to redirect_to("/en/menu/fields/f1")
      follow_redirect!
      expect(response.body).to include("Road field").and include(I18n.t("fields.create.added")).and include("Clarion loam")
      expect(response.body).to include(I18n.t("fields.preview.own_title"))

      get "/en/menu/fields"
      expect(response.body).not_to include(I18n.t("fields.sample.north"))
    end

    it "skips the farm questions already answered for the next field" do
      add_field
      get "/en/menu/fields/new"

      expect(response.body).not_to include(CGI.escapeHTML(I18n.t("fields.new.steps.location.question")))
      expect(response.body).not_to include(CGI.escapeHTML(I18n.t("fields.new.steps.water.question")))
      expect(response.body).to include(CGI.escapeHTML(I18n.t("fields.new.steps.crop.question")))
      expect(response.body).to include(CGI.escapeHTML(I18n.t("fields.new.steps.inputs.question")))
    end

    it "goes back to the sample farm on start over" do
      add_field
      delete "/en/menu/fields/preview"
      follow_redirect!

      expect(response.body).to include(I18n.t("fields.preview.sample_title")).and include(I18n.t("fields.sample.north"))
    end
  end

  it "lists every datum with its sources and the gaps" do
    get "/en/menu/fields/sources"

    expect(response).to have_http_status(:ok)
    (profile.data(:farm) + profile.data(:field)).each do |datum|
      expect(response.body).to include(CGI.escapeHTML(I18n.t("fields.data.#{datum.key}.label")))
    end
    expect(response.body).to include("SoilGrids (ISRIC)").and include(I18n.t("fields.sources.gaps_title"))
  end

  it "links the menu's fields panel to these screens" do
    get "/en/menu"
    expect(response.body).to include('href="/en/menu/fields"').and include('href="/en/menu/fields/new"')
  end
end
