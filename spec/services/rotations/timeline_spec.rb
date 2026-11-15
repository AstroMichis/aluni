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

  it "covers a perennial stand all year and leaves an unknown season blank" do
    line = timeline.for(%w[medicago-sativa medicago-sativa secale-cereale])

    expect(line.seasons.first(2).flatten).to all(be_growing)
    expect(line.seasons.last.map(&:state).uniq).to eq([ "unknown" ])
  end
end
