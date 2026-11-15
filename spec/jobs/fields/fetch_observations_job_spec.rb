require "rails_helper"

RSpec.describe Fields::FetchObservationsJob do
  let(:user) { create(:user) }
  let(:farm) { create(:farm, user: user, country_code: nil) }

  it "stores one observation per source for a US pin and places the farm" do
    stub_all_data_sources(us: true)
    field = create(:field, farm: farm, latitude: 40.95, longitude: -97.50)

    described_class.perform_now(field.id)

    expect(field.observations.pluck(:source, :status).to_h).to eq(
      "fcc" => "ok", "nasa_power" => "ok", "gaez" => "ok", "vegetation" => "ok", "nasadem" => "ok", "ssurgo" => "ok", "usgs_elevation" => "ok", "cdl" => "ok")
    expect(field.observation("vegetation").payload["months"].size).to eq(6)
    expect(field.observation("gaez").payload.dig("crops", "Maize", "yield")).to eq(6867.0)
    expect(field.observation("cdl").payload["years"]).to include((Date.current.year - 1).to_s => "Corn")
    expect(farm.reload).to have_attributes(country_code: "US", admin_area: "Nebraska")
  end

  it "keeps only the global layer outside the US" do
    stub_all_data_sources(us: false)
    field = create(:field, farm: farm, latitude: 9.93, longitude: -84.08)

    described_class.perform_now(field.id)

    expect(field.observations.where(source: %w[ssurgo usgs_elevation cdl]).pluck(:status).uniq).to eq([ "out_of_coverage" ])
    expect(field.observation("nasa_power")).to be_ok
    expect(field.observation("nasadem").payload).to eq("elevation" => 74.0, "slope" => 3.2)
    expect(a_request(:post, /sdmdataaccess/)).not_to have_been_made
  end

  it "records a failing source and still runs the others" do
    stub_all_data_sources(us: true)
    stub_request(:get, %r{gaez-services\.fao\.org/.+/query}).to_return(status: 500)
    field = create(:field, farm: farm, latitude: 40.95, longitude: -97.50)

    described_class.perform_now(field.id)

    expect(field.observation("gaez")).to be_failed
    expect(field.observation("gaez").error).to include("Gaez::Client")
    expect(field.observation("nasa_power")).to be_ok
  end

  it "records the vegetation source as failed when Planetary Computer cannot be searched" do
    stub_all_data_sources(us: false)
    allow_any_instance_of(PlanetaryComputer::Client).to receive(:monthly_ndvi).and_return(nil)
    field = create(:field, farm: farm, latitude: 9.93, longitude: -84.08)

    described_class.perform_now(field.id)

    expect(field.observation("vegetation")).to be_failed
    expect(field.observation("nasa_power")).to be_ok
  end

  context "when Planetary Computer rate-limits the NDVI" do
    def rate_limit!
      allow_any_instance_of(PlanetaryComputer::Client).to receive(:monthly_ndvi).and_return(nil)
      allow_any_instance_of(PlanetaryComputer::Client).to receive(:rate_limited?).and_return(true)
    end

    it "asks again later for the vegetation only" do
      stub_all_data_sources(us: false)
      rate_limit!
      field = create(:field, farm: farm, latitude: 9.93, longitude: -84.08)

      expect { described_class.perform_now(field.id) }
        .to have_enqueued_job(described_class).with(field.id, only: "vegetation", attempt: 1)
      expect(field.observation("vegetation")).to be_failed
    end

    it "runs only the vegetation on the retry and gives up after the last attempt" do
      stub_all_data_sources(us: false)
      field = create(:field, farm: farm, latitude: 9.93, longitude: -84.08)
      described_class.perform_now(field.id)
      rate_limit!

      expect { described_class.perform_now(field.id, only: "vegetation", attempt: 1) }
        .to have_enqueued_job(described_class).with(field.id, only: "vegetation", attempt: 2)
      expect(field.observation("vegetation")).to be_failed
      expect(field.observation("nasa_power")).to be_ok
      expect { described_class.perform_now(field.id, only: "vegetation", attempt: described_class::VEGETATION_RETRIES) }
        .not_to have_enqueued_job(described_class)
    end

    it "does not retry other failures" do
      stub_all_data_sources(us: false)
      allow_any_instance_of(PlanetaryComputer::Client).to receive(:monthly_ndvi).and_return(nil)
      field = create(:field, farm: farm, latitude: 9.93, longitude: -84.08)

      expect { described_class.perform_now(field.id) }.not_to have_enqueued_job(described_class)
    end
  end

  it "is enqueued when a pin is set or moved, not for other edits" do
    field = create(:field, :unlocated, farm: farm)
    expect { field.update!(latitude: 40.95, longitude: -97.5) }.to have_enqueued_job(described_class).with(field.id)
    expect { field.update!(name: "Renamed") }.not_to have_enqueued_job(described_class)
  end
end
