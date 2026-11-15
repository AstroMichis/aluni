require "rails_helper"

RSpec.describe Fields::SeasonLayoutService do
  let(:user) { create(:user) }
  let(:farm) { create(:farm, user: user) }
  let(:field) { create(:field, farm: farm, area: 2, area_unit: :hectares) }
  let(:year) { Date.current.year }

  def call(crops, year: self.year) = described_class.call(user: user, field: field.id, year: year, crops: crops)

  it "splits a 2 ha field into 1 ha of corn and 1 ha of beans, placing the cells as bands" do
    result = call([ { crop: "Corn", share: 0.5 }, { crop: "Beans", share: 0.5 } ])

    expect(result).to be_success
    corn, beans = field.field_crops.where(season_year: year).order(:id)
    expect(corn).to have_attributes(crop_name: "Corn", scientific_name: "Zea mays", share: 0.5, source: "farmer")
    expect(beans).to have_attributes(scientific_name: "Phaseolus vulgaris", share: 0.5)
    expect(corn.cells).to eq(Fields::CellLayout::COLUMN_ORDER.first(50).sort)
    expect((corn.cells + beans.cells).sort).to eq((0...100).to_a)
  end

  it "keeps the cells painted on the map and leaves the rest unplanted" do
    call([ { crop: "Corn", share: 0.3, cells: (0...30).to_a.join(",") }, { crop: "Beans", share: 0.2, cells: (80...100).to_a } ])

    corn, beans = field.field_crops.order(:id)
    expect(corn.cells).to eq((0...30).to_a)
    expect(beans.cells).to eq((80...100).to_a)
  end

  it "places again cells that no longer match the share (the form without JavaScript)" do
    call([ { crop: "Corn", share: 0.25, cells: (0...50).to_a } ])
    expect(field.field_crops.sole.cells.size).to eq(25)
  end

  it "stores one crop on the whole field as a whole field" do
    create(:field_crop, field: field, season_year: year, crop_name: "Corn", share: 0.5, cells: (0...50).to_a)

    call([ { crop: "Wheat", share: 1 } ])

    expect(field.field_crops.sole).to have_attributes(crop_name: "Wheat", share: nil, cells: [])
  end

  it "keeps a staying crop's months and source and drops the crops left out" do
    corn = create(:field_crop, field: field, season_year: year, crop_name: "Corn", planting_month: 4, harvest_month: 10, source: :cdl)
    create(:field_crop, field: field, season_year: year - 1, crop_name: "Beans", scientific_name: "Phaseolus vulgaris")

    call([ { crop: "Corn", share: 0.6 }, { crop: "Sorghum", share: 0.4 } ])

    expect(corn.reload).to have_attributes(share: 0.6, planting_month: 4, harvest_month: 10, source: "cdl")
    expect(field.field_crops.where(season_year: year).pluck(:crop_name)).to contain_exactly("Corn", "Sorghum")
    expect(field.field_crops.where(season_year: year - 1).count).to eq(1)
  end

  it "refuses what does not fit the field" do
    expect(call([ { crop: "Corn", share: 0.7 }, { crop: "Beans", share: 0.5 } ]).error[:code]).to eq(:over)
    expect(call([ { crop: "Corn", share: 0.5, cells: [ 1, 2 ] }, { crop: "Beans", share: 0.02, cells: [ 2, 3 ] } ]).error[:code]).to eq(:overlap)
    expect(call(Array.new(7) { |i| { crop: "Crop #{i}", share: 0.1 } }).error[:code]).to eq(:too_many)
    expect(call([ { crop: "Corn", share: 0.5 }, { crop: "maize", share: 0.5 } ]).error[:code]).to eq(:duplicate)
    expect(call([ { crop: "Corn", share: 0.5 }, { crop: "Beans" } ]).error[:code]).to eq(:share)
    expect(call([ { crop: "Corn" } ], year: year + 2).error[:code]).to eq(:year)
    expect(described_class.call(user: create(:user), field: field.id, year: year, crops: []).error[:code]).to eq(:not_found)
    expect(field.field_crops).to be_empty
  end
end
