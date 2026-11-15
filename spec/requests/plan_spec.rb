require "rails_helper"

RSpec.describe "Action plan page", type: :request do
  let(:app_name) { I18n.t("app_name") }

  def text(key, locale)
    CGI.escapeHTML(I18n.t(key, locale: locale, app_name: app_name))
  end

  %w[en es].each do |locale|
    it "renders the proposal in #{locale} with every section, the figures and the BOM notes" do
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
      expect(body).to include(text("plan.show.sections.t5d.title", locale))
      expect(body.scan(text("plan.show.notes.bom", locale)).size).to be >= 6
      expect(body).to include(text("plan.show.notes.register", locale))
      expect(body).to include(%(href="#{evidence_path(locale: locale)}"))
      expect(body).to include('class="plan__label plan__label--verified">[VERIFIED: docs/DEVICES.md]</span>')
      expect(body).not_to include("—")
    end
  end

  it "shows the new Sonda section, not the old priced BOM table" do
    get plan_path(locale: "en")

    expect(response.body).to include("no final unit BOM or retail price is stated")
    expect(response.body).not_to include("Seeed S-Soil MT-02B (capacitive")
  end
end
