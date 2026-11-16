require "rails_helper"

RSpec.describe Rotations::Timeline do
  let(:user) { create(:user) }
  let!(:record) { create_farm_for(user) }
  let(:field) { Fields::Farm.for(user).field(record.id) }
  let(:year) { Date.current.year + 1 }
  let(:timeline) { described_class.new(field, first_year: year) }

  def months_of(line, state) = line.months.select { |m| m.state == state }.map { |m| [ m.year, m.month ] }

  it "lays the seasons on 36 months from FAO-56 planting months and stages" do
    line = timeline.for(%w[glycine-max zea-mays glycine-max])

    expect(line.months.size).to eq(36)
    # Soybeans: FAO-56 May, 135 days (5 months). Corn is the current crop: its own April to October.
    expect(months_of(line, "crop").first(5)).to eq((5..9).map { |m| [ year, m ] })
    expect(months_of(line, "crop")[5, 7]).to eq((4..10).map { |m| [ year + 1, m ] })
    expect(line.bare).to eq(36 - 17)
  end

  it "marks bare months under frost, drought or storms as vulnerable" do
    months = (1..12).map { |m| { "month" => m, "heavy_days" => m == 10 ? 1.5 : 0.1 } }
    create(:field_observation, field: record, source: "gpm_imerg", payload: { "years" => 20, "months" => months })
    line = described_class.new(Fields::Farm.for(user).field(record.id), first_year: year).for(%w[glycine-max zea-mays glycine-max])

    expect(timeline.weather[3]).to include("frost") # 20.7 frost days in March
    expect(timeline.weather[7]).to include("dry") # 2.5 mm/day of rain against 5.6 mm/day of reference evapotranspiration
    expect(timeline.weather[1]).not_to include("dry") # 0.6 against 0.7: little rain, but little demand
    october = line.months.find { |m| m.year == year && m.month == 10 }
    expect(october).to be_bare
    expect(october.risks).to include("storm")
    expect(october).to be_vulnerable
    expect(line.stormy_bare).to eq(2) # October of the soybean seasons; the corn is still in the ground
    # A crop that has closed its canopy protects the soil; a young one does not (FAO-56 effective full cover).
    expect(line.months.select { |m| m.growing? && !m.establishing? }).to all(satisfy { |m| !m.vulnerable? })
    expect(line.months.select(&:vulnerable?)).to all(be_open_soil)
  end

  it "counts a young crop's months before FAO-56 full cover as open soil" do
    line = timeline.for(%w[glycine-max zea-mays glycine-max])
    young = ->(crop, season) { line.months.select { |m| m.crop == crop && m.year == year + season && m.establishing? }.map(&:month) }

    # Soybeans (planted in May): initial 20 + development 30 days, so May and June are still open.
    expect(young.call("glycine-max", 0)).to eq([ 5, 6 ])
    # Corn on the field's own April planting: initial 30 + development 40 days, so April and May.
    expect(young.call("zea-mays", 1)).to eq([ 4, 5 ])
    expect(line.establishing).to eq(6)
    expect(line.exposed_with_cover).to be >= line.vulnerable.count(&:establishing?) # a cover crop cannot sit under a young crop
  end

  it "plants by the region's calendar (USDA NASS progress) before the FAO-56 row" do
    record.field_crops.find_by(crop_name: "Corn").update!(planting_month: nil, harvest_month: nil)
    corn_months = lambda do |area|
      record.farm.update!(country_code: "US", admin_area: area)
      line = described_class.new(Fields::Farm.for(user).field(record.id), first_year: year).for(%w[zea-mays glycine-max zea-mays])
      line.months.select { |m| m.crop == "zea-mays" && m.year == year }.map(&:month)
    end

    expect(corn_months.call("Nevada")).to eq((4..8).to_a)   # no NASS calendar here: the FAO-56 row, April
    expect(corn_months.call("iowa")).to eq((5..9).to_a)     # Iowa: half the corn is planted by about 6 May
  end

  it "reads dry months from the IMERG rain when the field has it" do
    expect(timeline.weather[7]).to include("dry") # POWER only: 2.5 mm/day against 5.6 of demand

    months = (1..12).map { |m| { "month" => m, "heavy_days" => 0.1, "rain_mm" => m == 7 ? 150 : 40 } }
    create(:field_observation, field: record, source: "gpm_imerg", payload: { "years" => 20, "months" => months })
    with_imerg = described_class.new(Fields::Farm.for(user).field(record.id), first_year: year)

    expect(with_imerg.weather[7]).not_to include("dry") # IMERG: 150 mm in July, about 4.8 mm/day
  end

  it "uses the field's own months for its current crop and carries a southern season into January" do
    record.update!(latitude: -41.32, longitude: -72.98)
    record.field_crops.find_by(crop_name: "Corn").update!(planting_month: 10, harvest_month: 3)
    southern = described_class.new(Fields::Farm.for(user).field(record.id), first_year: Date.current.year + 1)

    line = southern.for(%w[glycine-max zea-mays glycine-max])
    first = line.months.first(3)

    # The corn planted in October of this season is in the ground until March.
    expect(first.map(&:state)).to eq(%w[crop crop crop])
    expect(first.map(&:crop).uniq).to eq([ "zea-mays" ])
    # Soybeans follow the southern calendar: November to March.
    soy = line.months.select { |m| m.crop == "glycine-max" }.map { |m| [ m.year - (Date.current.year + 1), m.month ] }
    expect(soy.first(5)).to eq([ [ 0, 11 ], [ 0, 12 ], [ 1, 1 ], [ 1, 2 ], [ 1, 3 ] ])
  end

  it "proposes a cover crop for each bare window of two months or more, by its weather" do
    line = timeline.for(%w[glycine-max zea-mays glycine-max])
    first = line.windows.first

    span = ->(w) { [ w.first.year, w.first.month, w.last.year, w.last.month ] }

    # Bare until the soybeans in May, then from October until the corn in April of the next year.
    expect(line.windows.first(2).map(&span)).to eq([ [ year, 1, year, 4 ], [ year, 10, year + 1, 3 ] ])
    expect([ first.kind, first.cover ]).to eq([ "frost", "secale-cereale" ]) # 20.7 frost days in March
    expect(line.windows.first(1).map(&:exposed)).to all(be_positive)
    expect(line.exposed_with_cover).to eq(line.vulnerable.size - line.windows.sum { |w| w.months.drop(1).count(&:vulnerable?) })
    expect(line.exposed_with_cover).to be >= line.windows.count { |w| w.first.vulnerable? } # each window's first month stays exposed
    expect(line.window_for(first.months.first)).to eq(first)
  end

  it "picks a warm-season legume where the window is warm and frost-free" do
    climatology = field.observation("nasa_power").payload["climatology"]
    climatology["FROST_DAYS"] = climatology["FROST_DAYS"].transform_values { 0.0 }
    climatology["T2M"] = climatology["T2M"].transform_values { 24.0 }
    record.observations.find_by(source: "nasa_power").update!(payload: field.observation("nasa_power").payload.merge("climatology" => climatology))
    line = described_class.new(Fields::Farm.for(user).field(record.id), first_year: year).for(%w[glycine-max zea-mays glycine-max])

    expect(line.windows.map(&:cover).uniq).to eq([ "vigna-unguiculata" ])
  end

  it "keeps a second crop the field grows after the same main crop" do
    # Last season: soybeans as the main crop, then wheat sown after them (as the history records it).
    create(:field_crop, field: record, role: :second, crop_name: "Wheat", scientific_name: "Triticum aestivum",
                        season_year: Date.current.year - 1, planting_month: nil, harvest_month: nil)
    line = described_class.new(Fields::Farm.for(user).field(record.id), first_year: year).for(%w[glycine-max zea-mays glycine-max])

    wheat = line.months.select { |m| m.crop == "triticum-aestivum" }.map { |m| [ m.year, m.month ] }
    # Soybeans May-September, then wheat from October for its FAO-56 length (135 days: 5 months).
    expect(wheat.first(5)).to eq([ [ year, 10 ], [ year, 11 ], [ year, 12 ], [ year + 1, 1 ], [ year + 1, 2 ] ])
    expect(line.months.select { |m| m.crop == "zea-mays" }.map(&:month)).to eq((4..10).to_a) # the corn keeps its months
    expect(wheat.select { |y, _| y == year + 2 }.map(&:last)).to eq([ 10, 11, 12 ]) # after the third season's soybeans
  end

  it "moves the weather strip under a warmer climate: fewer frost months, more dry ones" do
    hot = described_class.new(field, first_year: year, scenario: Weather::Scenario.find("warm2_dry"))
    count = ->(t, risk) { t.weather.values.count { |risks| risks.include?(risk) } }

    expect(count.call(hot, "frost")).to be <= count.call(timeline, "frost")
    expect(count.call(hot, "dry")).to be >= count.call(timeline, "dry")
    expect(count.call(hot, "dry") + count.call(timeline, "frost")).to be > count.call(timeline, "dry") + count.call(hot, "frost")
  end

  it "covers a perennial stand all year and leaves an unknown season blank" do
    line = timeline.for(%w[medicago-sativa medicago-sativa secale-cereale])

    expect(line.seasons.first(2).flatten).to all(be_growing)
    expect(line.seasons.last.map(&:state).uniq).to eq([ "unknown" ])
  end
end
