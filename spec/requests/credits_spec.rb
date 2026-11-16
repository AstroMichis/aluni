require "rails_helper"

RSpec.describe "Credits page", type: :request do
  let(:credits) { CreditsController.registry }

  it "renders every source with its reference, what, why, where in the code, and its credit line" do
    get credits_path(locale: "en")

    expect(response).to have_http_status(:ok)
    body = response.body
    expect(body).to include('lang="en"').and include(CGI.escapeHTML(I18n.t("credits.show.headline", app_name: I18n.t("app_name"))))
    expect(body).to include(I18n.t("credits.show.tally.sources", count: credits.size))
    credits.each do |id, credit|
      expect(body).to include(%(id="credit-#{id}"))
      expect(body).to include(CGI.escapeHTML(credit["name"]))
      expect(body).to include(CGI.escapeHTML(I18n.t("credits.show.sources.#{id}.why", app_name: I18n.t("app_name"))))
      expect(body).to include(credit["code"].first.first)
      expect(body).to include(%(href="https://doi.org/#{credit['doi']}")) if credit["doi"]
      expect(body).to include(CGI.escapeHTML(credit.dig("attribution", "required"))) if credit.dig("attribution", "required")
    end
    expect(body).to include("docs/proposal/credits_audit.rb")
    expect(body).to include(%(href="#{evidence_path(locale: "en")}")).and include(%(href="#{plan_path(locale: "en")}"))
  end

  it "renders in Spanish under /es, with the references kept in English" do
    get credits_path(locale: "es")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('lang="es"').and include(I18n.t("credits.show.sources.grace.why", locale: :es))
    expect(response.body).to include(%(<p class="credits__apa" lang="en">))
  end

  it "covers every source the field job fetches" do
    observed = YAML.safe_load_file(Rails.root.join("config/field_profile.yml")).fetch("observations").keys
    names = { "fcc" => "fcc_census_block", "usgs_elevation" => "usgs_3dep", "vegetation" => "sentinel2", "modis" => "modis_ndvi" }
    observed.each { |source| expect(credits).to have_key(names.fetch(source, source)) }
  end

  it "is linked from the judges' strip on the landing page" do
    get root_path(locale: "en")

    expect(response.body).to include(%(href="#{credits_path(locale: "en")}")).and include(I18n.t("shared.judges_bar.credits.title"))
  end
end
