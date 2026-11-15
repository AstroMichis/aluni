require "rails_helper"

RSpec.describe Crops::PlantingCalendar do
  it "answers the month half a state's crop is planted (USDA NASS progress)" do
    expect(described_class.month("zea-mays", country_code: "US", admin_area: "Iowa")).to eq(5)
    expect(described_class.month("Soybeans", country_code: "us", admin_area: " iowa ")).to eq(5)
    expect(described_class.entry("zea-mays", country_code: "US", admin_area: "Iowa")).to include("planted_50", "years")
  end

  it "answers nil where there is no calendar, so the caller falls back to FAO-56" do
    expect(described_class.month("zea-mays", country_code: "US", admin_area: "Atlantis")).to be_nil
    expect(described_class.month("zea-mays", country_code: "CL", admin_area: "Iowa")).to be_nil
    expect(described_class.month("medicago-sativa", country_code: "US", admin_area: "Iowa")).to be_nil
    expect(described_class.month("zea-mays")).to be_nil
  end
end
