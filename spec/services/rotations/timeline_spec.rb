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
    expect(line.months.select(&:growing?)).to all(satisfy { |m| !m.vulnerable? })
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

  it "covers a perennial stand all year and leaves an unknown season blank" do
    line = timeline.for(%w[medicago-sativa medicago-sativa secale-cereale])

    expect(line.seasons.first(2).flatten).to all(be_growing)
    expect(line.seasons.last.map(&:state).uniq).to eq([ "unknown" ])
  end
end
