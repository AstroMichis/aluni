require "rails_helper"

RSpec.describe Fields::SaveSetupService, type: :service do
  let(:user) { create(:user, locale: "es") }
  let(:attributes) do
    { "latitude" => 42.0, "longitude" => -93.75, "place_label" => "Ames, Iowa", "country_code" => "US", "admin_area" => "Iowa",
      "location_source" => "geolocation", "crop_name" => "maíz", "irrigation" => "irrigated", "area" => 12.5, "area_unit" => "acres" }
  end

  it "writes the field, the farm, the crop and the units, and completes the onboarding" do
    result = described_class.call(user: user, attributes: attributes)

    expect(result).to be_success
    field = result.value[:field]
    expect(field).to eq(user.farms.first.fields.first)
    expect(field).to have_attributes(
      latitude: 42.0, longitude: -93.75, location_confidence: "confirmed", location_source: "geolocation",
      place_label: "Ames, Iowa", area: 12.5, area_unit: "acres", irrigation: "irrigated"
    )
    expect(user.farms.first).to have_attributes(country_code: "US", admin_area: "Iowa")
    crop = field.field_crops.sole
    expect(crop).to have_attributes(crop_name: "Maíz", scientific_name: "Zea mays", season_year: Date.current.year, role: "main", source: "farmer")
    expect(user.farmer_profile.units).to eq("imperial")
    expect(user.reload).to be_onboarding_complete
    expect(user.onboarding_session.completed_at).to be_present
  end

  it "updates the same rows on a second call without a duplicate crop" do
    described_class.call(user: user, attributes: attributes)
    again = described_class.call(user: user, attributes: attributes.merge("latitude" => 42.1, "crop_name" => "soya", "country_code" => "CO", "area" => 3))

    expect(again).to be_success
    expect(user.farms.count).to eq(1)
    expect(Field.where(farm: user.farms).count).to eq(1)
    field = again.value[:field]
    expect(field.latitude).to eq(42.1)
    expect(field.area).to eq(3)
    expect(field.field_crops.count).to eq(1)
    expect(field.field_crops.sole).to have_attributes(crop_name: "Soya", scientific_name: "Glycine max")
    expect(user.farms.first.country_code).to eq("CO")
    expect(user.farmer_profile.reload.units).to eq("metric")
  end

  it "accepts the pin alone: map source, no crop, no area, units untouched" do
    result = described_class.call(user: user, attributes: { "latitude" => "4.6", "longitude" => "-74.08" })

    expect(result).to be_success
    field = result.value[:field]
    expect(field).to have_attributes(latitude: 4.6, longitude: -74.08, location_source: "map", location_confidence: "confirmed", area: nil, irrigation: "unknown")
    expect(field.field_crops).to be_empty
    expect(user.farmer_profile.units).to eq("metric")
    expect(user).to be_onboarding_complete
  end

  it "normalises an unknown crop through Crops::NormalizeService with the person's language" do
    allow(Crops::NormalizeService).to receive(:call).with(text: "lulo", locale: "es")
                                                    .and_return(Success(crop_name: "Lulo", scientific_name: "Solanum quitoense", confidence: "high"))

    result = described_class.call(user: user, attributes: attributes.merge("crop_name" => "lulo"))

    expect(result.value[:field].field_crops.sole).to have_attributes(crop_name: "Lulo", scientific_name: "Solanum quitoense")
  end

  it "keeps a crop that comes with its scientific name as given" do
    expect(Crops::NormalizeService).not_to receive(:call)

    result = described_class.call(user: user, attributes: attributes.merge("crop_name" => "Papa criolla", "scientific_name" => "Solanum phureja"))

    expect(result.value[:field].field_crops.sole).to have_attributes(crop_name: "Papa criolla", scientific_name: "Solanum phureja")
  end

  it "fails without a pin and creates nothing" do
    result = described_class.call(user: user, attributes: { "crop_name" => "maíz" })

    expect(result.error).to include(code: :invalid)
    expect(result.error[:messages]).to eq([ I18n.t("finder.errors.pin_required") ])
    expect(user.farms).to be_empty
    expect(user).not_to be_onboarding_complete
  end

  it "drops values it does not know and clips text" do
    result = described_class.call(user: user, attributes: attributes.merge(
      "irrigation" => "sprinklers-everywhere", "area_unit" => "furlongs", "location_source" => "carrier pigeon",
      "place_label" => "x" * 150, "area" => "-4", "country_code" => "usa"
    ))

    field = result.value[:field]
    expect(field).to have_attributes(irrigation: "unknown", area_unit: "hectares", location_source: "map", area: nil)
    expect(field.place_label.length).to eq(100)
    expect(user.farms.first.country_code).to be_nil
  end

  describe ".coerce" do
    it "turns the finder's flat strings into clean attributes, or nil without a pin" do
      attrs = described_class.coerce("latitude" => "42.0", "longitude" => "-93.75", "area" => "12.5", "irrigation" => "rainfed", "country_code" => "co", "bogus" => "x")

      expect(attrs).to eq("latitude" => 42.0, "longitude" => -93.75, "area" => 12.5, "irrigation" => "rainfed", "country_code" => "CO")
      expect(described_class.coerce("latitude" => "42.0")).to be_nil
      expect(described_class.coerce(nil)).to be_nil
    end
  end
end
