require "rails_helper"

RSpec.describe Reports::Export do
  subject(:export) { described_class.new(Fields::Farm.build(Fields::Farm.sample_data), profile: Fields::Profile.current) }

  it "quotes CSV cells with commas or quotes" do
    csv = export.to_csv
    expect(csv).to include(%(north,soil_type,confirmed,"Clarion loam, Bemis moraine, 6 to 10 percent slopes",SSURGO,parcel,high))
    expect(csv).to end_with("\r\n")
  end

  it "holds one row per datum per subject" do
    profile = Fields::Profile.current
    expect(export.rows.size).to eq(profile.data(:farm).size + (3 * profile.data(:field).size))
  end
end
