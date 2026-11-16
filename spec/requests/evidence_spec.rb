require "rails_helper"

RSpec.describe "Evidence page", type: :request do
  let(:snapshot) { EvidenceController.snapshot }

  it "renders the eight studies with their verdicts and the snapshot's numbers" do
    get evidence_path(locale: "en")

    expect(response).to have_http_status(:ok)
    body = response.body
    expect(body).to include('lang="en"').and include(CGI.escapeHTML(I18n.t("evidence.show.headline", app_name: I18n.t("app_name"))))
    EvidenceController::STUDIES.each do |id|
      expect(body).to include(%(id="study-#{id}"))
      expect(body).to include(CGI.escapeHTML(I18n.t("evidence.show.studies.#{id}.question", app_name: I18n.t("app_name"))))
    end
    studies = snapshot["studies"]
    expect(body).to include("#{studies.dig('v4', 'gain')} % more").and include("#{studies.dig('v1', 'gauges')} CoCoRaHS")
    expect(body).to include("$#{ActiveSupport::NumberHelper.number_to_delimited(studies.dig('v7', 'farmer'))}")
    expect(body).to include("rises to #{studies.dig('v8', 'app_rule_agreement')} %")
    expect(body).to include(I18n.t("evidence.show.verdicts.pass")).and include(I18n.t("evidence.show.verdicts.fail"))
    expect(body).to include("docs/proposal/validation/run_all.rb")
    expect(body).to include(%(href="#{plan_path(locale: "en")}"))
  end

  it "renders in Spanish under /es" do
    get evidence_path(locale: "es")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('lang="es"').and include(CGI.escapeHTML(I18n.t("evidence.show.studies.v4.question", locale: :es)))
  end

  it "lists the backtest fixes the app has made and the ones still open" do
    get evidence_path(locale: "en")

    EvidenceController::FIXES.each_key { |key| expect(response.body).to include(key.upcase.sub("U", "U-")) }
    expect(response.body).to include(I18n.t("evidence.show.fix_status.done")).and include(I18n.t("evidence.show.fix_status.open"))
  end

  it "compares every study on the second field when the snapshot has one" do
    york = snapshot.dig("sites", "york")
    skip "no second field in the snapshot" unless york

    get evidence_path(locale: "en")

    body = response.body
    expect(body).to include(%(id="second-field")).and include(york.dig("field", "place"))
    expect(body).to include("Correlation with yields: #{york.dig('studies', 'v2', 'r_corn')} corn")
    EvidenceController::STUDIES.each { |id| expect(body).to include(CGI.escapeHTML(I18n.t("evidence.show.sites.names.#{id}"))) }
    expect(body).to include(CGI.escapeHTML(I18n.t("evidence.show.sites.buin")))
  end

  it "is linked from the reviewers' strip on the landing page, next to the action plan" do
    get "/en"

    expect(response.body).to include('class="judges-bar"')
    expect(response.body).to include(%(href="#{evidence_path(locale: "en")}")).and include(%(href="#{plan_path(locale: "en")}"))
    expect(response.body).to include(I18n.t("shared.judges_bar.evidence.title")).and include(I18n.t("shared.judges_bar.plan.title"))
  end
end
