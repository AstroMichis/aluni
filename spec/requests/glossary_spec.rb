require "rails_helper"

RSpec.describe "Glossary" do
  it "explains every term, in both languages, without signing in" do
    %w[en es].each do |locale|
      get glossary_path(locale: locale)

      expect(response).to have_http_status(:ok)
      GlossaryController::TERMS.each do |term|
        expect(response.body).to include(%(id="#{term}")).and include(ERB::Util.h(I18n.t("glossary.terms.#{term}.name", locale: locale)))
      end
    end
  end

  it "has an entry for every source the plan links to" do
    expect(GlossaryController::SOURCES.values - GlossaryController::TERMS).to be_empty
    expect(Rotations::Comparator::WATER_SOURCES.values - GlossaryController::SOURCES.keys).to be_empty # every water-need source links
  end
end
