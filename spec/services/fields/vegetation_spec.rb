require "rails_helper"

RSpec.describe Fields::Vegetation do
  def vegetation(values)
    rows = values.each_with_index.map { |v, i| { "month" => format("2026-%02d", i + 1), "ndvi" => v, "mission" => v && "landsat" } }
    described_class.new(build(:field_observation, source: "vegetation", status: :ok, payload: { "months" => rows }))
  end

  it "reads each month as bare, sparse or green" do
    expect(vegetation([ 0.1, 0.3, 0.6, nil ]).months.map(&:cover)).to eq([ "bare", "sparse", "green", nil ])
  end

  it "finds runs of bare months and the longest one" do
    veg = vegetation([ 0.1, 0.12, 0.2, 0.6, 0.7, 0.1, 0.05 ])

    expect(veg.bare_periods.map(&:months)).to eq([ 3, 2 ])
    expect(veg.longest_bare).to have_attributes(from: Date.new(2026, 1, 1), to: Date.new(2026, 3, 1), months: 3)
    expect(veg.bare_months).to eq(5)
    expect(veg.greenest.month).to eq("2026-05")
  end

  it "lets a month without a clear image break a bare run" do
    expect(vegetation([ 0.1, nil, 0.1 ]).bare_periods.map(&:months)).to eq([ 1, 1 ])
  end

  it "is not present without a usable observation" do
    expect(described_class.new(nil)).not_to be_present
    expect(vegetation([ nil, nil ])).not_to be_present
    expect(vegetation([ nil, 0.4 ])).to be_present
  end
end
