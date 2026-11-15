require "rails_helper"

RSpec.describe Fields::Zone do
  let(:user) { create(:user) }
  let(:record) { create(:field, farm: create(:farm, user: user), area: 2) }
  let(:year) { Date.current.year }

  def zones = Fields::Farm::Field.new(record.reload, profile: Fields::Profile.current).zones

  it "reads a field that was never split as one zone of every cell" do
    create(:field_crop, field: record, season_year: year, crop_name: "Corn")
    create(:field_crop, field: record, season_year: year - 1, crop_name: "Beans", scientific_name: "Phaseolus vulgaris")

    expect(zones.size).to eq(1)
    expect(zones.first).to have_attributes(cells: (0...100).to_a, share: 1.0, whole_field?: true)
    expect(zones.first.history.transform_values(&:crop_name)).to eq((year - 1).to_s => "Beans", year.to_s => "Corn")
  end

  it "follows each piece of ground: corn after beans on one half, beans after corn on the other" do
    left = Fields::CellLayout::COLUMN_ORDER.first(50)
    right = (0...100).to_a - left
    create(:field_crop, field: record, season_year: year - 1, crop_name: "Corn", share: 0.5, cells: left)
    create(:field_crop, field: record, season_year: year - 1, crop_name: "Beans", scientific_name: "Phaseolus vulgaris", share: 0.5, cells: right)
    create(:field_crop, field: record, season_year: year, crop_name: "Beans", scientific_name: "Phaseolus vulgaris", share: 0.5, cells: left)
    create(:field_crop, field: record, season_year: year, crop_name: "Corn", share: 0.5, cells: right)

    expect(zones.map { |z| z.history.values.map(&:crop_name) }).to contain_exactly(%w[Corn Beans], %w[Beans Corn])
    expect(zones.map(&:share)).to eq([ 0.5, 0.5 ])
  end

  it "keeps the unplanted part as a fallow zone last" do
    create(:field_crop, field: record, season_year: year, crop_name: "Corn", share: 0.75, cells: (0...75).to_a)

    expect(zones.map(&:fallow?)).to eq([ false, true ])
    expect(zones.last.cells).to eq((75...100).to_a)
  end
end
