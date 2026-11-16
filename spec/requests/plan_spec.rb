require "rails_helper"

RSpec.describe "Action plan page", type: :request do
  let(:app_name) { I18n.t("app_name") }

  def text(key, locale)
    CGI.escapeHTML(I18n.t(key, locale: locale, app_name: app_name))
  end

  %w[en es].each do |locale|
    it "renders the proposal in #{locale} with every section, the figures and the reference tests" do
      get plan_path(locale: locale)

      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body).to include(%(lang="#{locale}")).and include(text("plan.show.headline", locale))
      expect(body).to include(text("plan.show.version", locale))
      PlanController::SECTIONS.each do |key|
        expect(body).to include(text("plan.show.sections.#{key}.title", locale))
        expect(body).to include(%(href="#plan-#{key}")).and include(%(id="plan-#{key}"))
      end
      expect(body).to include("25,537.58", "5,226.50", "$493.73", "$507.53", "~$34.14")
      expect(body).to include("docs/proposal/claims_audit.rb", "docs/proposal/ames_worked_example.rb", "docs/proposal/validation/run_all.rb")
      expect(body).to include("U-27", "U-29", "U-32", "A-4")
      expect(body).to include(%(href="#{evidence_path(locale: locale)}"))
      expect(body).to include('class="plan__label plan__label--verified">[VERIFIED: docs/DEVICES.md]</span>')
      expect(body).not_to include("—")
    end
  end

  it "reads as a project proposal, not a team draft" do
    get plan_path(locale: "en")

    body = response.body
    expect(body).to include("1. Executive summary", "2. How Aluni answers the challenge", "11. Reference tests: rerun every number")
    expect(body).to include("40 of 40 reproduce", "24 of 24 checks pass")
    expect(body).not_to include("Draft for team review", "Open questions for the team", "Under revision", "Before submission", "Summary for the judges", "T5d")
  end

  it "shows the new Sonda section, not the old priced BOM table" do
    get plan_path(locale: "en")

    expect(response.body).to include("no final unit BOM or retail price is stated")
    expect(response.body).not_to include("Seeed S-Soil MT-02B (capacitive")
  end
end
