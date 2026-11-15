require "rails_helper"

RSpec.describe PlanetaryComputer::Client do
  let(:client) { described_class.new(cache: ActiveSupport::Cache::MemoryStore.new) }
  let(:search_url) { "https://planetarycomputer.microsoft.com/api/stac/v1/search" }
  let(:point_url) { %r{\Ahttps://planetarycomputer\.microsoft\.com/api/data/v1/item/point/-97\.5,40\.95} }
  let(:json) { { "Content-Type" => "application/geo+json" } }

  def scenes_body
    {
      type: "FeatureCollection",
      features: [
        { id: "S2B_CLEAR", properties: { datetime: "2025-08-14T17:18:59.024000Z", "eo:cloud_cover" => 13.7 } },
        { id: "S2C_CLOUDY_PIXEL", properties: { datetime: "2025-08-19T17:19:11.025000Z", "eo:cloud_cover" => 26.7 } }
      ]
    }.to_json
  end

  def point(value) = { coordinates: [ -97.5, 40.95 ], values: [ value ], band_names: [ "x" ] }.to_json

  def stub_point(item, expression, value)
    stub_request(:get, point_url)
      .with(query: hash_including("collection" => "sentinel-2-l2a", "item" => item, "expression" => expression))
      .to_return(status: 200, body: point(value), headers: { "Content-Type" => "application/json" })
  end

  it "searches Sentinel-2 scenes over the point, least cloudy first" do
    stub = stub_request(:post, search_url)
             .with { |req| JSON.parse(req.body).values_at("collections", "intersects") == [ [ "sentinel-2-l2a" ], { "type" => "Point", "coordinates" => [ -97.5, 40.95 ] } ] }
             .to_return(status: 200, body: scenes_body, headers: json)

    scenes = client.scenes(lat: 40.95, lon: -97.5, from: Date.new(2025, 7, 1), to: Date.new(2025, 8, 31))

    expect(scenes.map { |s| s[:id] }).to eq(%w[S2B_CLEAR S2C_CLOUDY_PIXEL])
    expect(scenes.first[:datetime]).to eq(Time.utc(2025, 8, 14, 17, 18, 59.024r))
    expect(stub).to have_been_requested
  end

  it "builds an NDVI series from clear pixels only" do
    stub_request(:post, search_url).to_return(status: 200, body: scenes_body, headers: json)
    stub_point("S2B_CLEAR", "SCL_b1", 4)
    stub_point("S2B_CLEAR", described_class::NDVI, 0.6402918872513951)
    stub_point("S2C_CLOUDY_PIXEL", "SCL_b1", 9)

    series = client.ndvi(lat: 40.95, lon: -97.5, from: Date.new(2025, 7, 1), to: Date.new(2025, 8, 31))

    expect(series).to eq([ { date: Date.new(2025, 8, 14), ndvi: 0.64, scene: "S2B_CLEAR", cloud_cover: 13.7 } ])
  end

  it "returns nil with the error when the search fails" do
    stub_request(:post, search_url).to_return(status: 400, body: "bad query")

    expect(client.scenes(lat: 40.95, lon: -97.5, from: Date.new(2025, 7, 1), to: Date.new(2025, 8, 31))).to be_nil
    expect(client.last_error).to include(type: :api_error, status: 400)
  end

  it "refuses to call while the service is paused" do
    create(:platform_switch, service: "planetary_computer", paused: true)

    expect { client.scenes(lat: 1, lon: 1, from: Date.current, to: Date.current) }.to raise_error(Platform::ServicePaused)
  end

  describe "#monthly_ndvi" do
    let(:today) { Date.new(2025, 8, 20) }

    it "keeps one clear NDVI per month from Landsat and Sentinel-2, oldest first" do
      landsat = { type: "FeatureCollection", features: [
        { id: "LC09_CLOUDY_PIXEL", collection: "landsat-c2-l2", properties: { datetime: "2025-07-10T17:12:00Z", "eo:cloud_cover" => 5.0 } },
        { id: "S2B_JULY", collection: "sentinel-2-l2a", properties: { datetime: "2025-07-14T17:18:59Z", "eo:cloud_cover" => 8.0 } }
      ] }.to_json
      august = { type: "FeatureCollection", features: [
        { id: "LC09_AUGUST", collection: "landsat-c2-l2", properties: { datetime: "2025-08-02T17:12:41Z", "eo:cloud_cover" => 9.5 } }
      ] }.to_json
      stub_request(:post, search_url).with { |req| JSON.parse(req.body)["datetime"].start_with?("2025-07") }.to_return(status: 200, body: landsat, headers: json)
      stub_request(:post, search_url).with { |req| JSON.parse(req.body)["datetime"].start_with?("2025-08") }.to_return(status: 200, body: august, headers: json)
      stub_request(:get, point_url).with(query: hash_including("item" => "LC09_CLOUDY_PIXEL", "expression" => "qa_pixel_b1"))
                                   .to_return(status: 200, body: point(23_888), headers: { "Content-Type" => "application/json" }) # cloud shadow bit
      stub_point("S2B_JULY", "SCL_b1", 4)
      stub_point("S2B_JULY", described_class::NDVI, 0.64)
      stub_request(:get, point_url).with(query: hash_including("item" => "LC09_AUGUST", "expression" => "qa_pixel_b1"))
                                   .to_return(status: 200, body: point(21_824), headers: { "Content-Type" => "application/json" }) # clear
      ndvi = stub_request(:get, point_url).with(query: hash_including("item" => "LC09_AUGUST", "expression" => described_class::LANDSAT_NDVI, "unscale" => "true"))
                                          .to_return(status: 200, body: point(0.57), headers: { "Content-Type" => "application/json" })

      rows = client.monthly_ndvi(lat: 40.95, lon: -97.5, months: 2, today: today)

      expect(rows).to eq([
        { "month" => "2025-07", "ndvi" => 0.64, "date" => "2025-07-14", "mission" => "sentinel-2", "scene" => "S2B_JULY" },
        { "month" => "2025-08", "ndvi" => 0.57, "date" => "2025-08-02", "mission" => "landsat", "scene" => "LC09_AUGUST" }
      ])
      expect(ndvi).to have_been_requested
    end

    it "leaves a month without a clear view empty" do
      stub_request(:post, search_url).to_return(status: 200, body: { type: "FeatureCollection", features: [] }.to_json, headers: json)

      expect(client.monthly_ndvi(lat: 40.95, lon: -97.5, months: 2, today: today)).to eq([
        { "month" => "2025-07", "ndvi" => nil }, { "month" => "2025-08", "ndvi" => nil }
      ])
    end

    it "returns nil with the error when a search fails" do
      stub_request(:post, search_url).to_return(status: 400, body: "bad query")

      expect(client.monthly_ndvi(lat: 40.95, lon: -97.5, months: 2, today: today)).to be_nil
      expect(client.last_error).to include(type: :api_error, status: 400)
    end

    it "retries a rate limit with backoff, then reports it and stops asking" do
      fast = described_class.new(cache: ActiveSupport::Cache::MemoryStore.new,
                                 retry_options: described_class::RETRY.merge(interval: 0, interval_randomness: 0))
      search = stub_request(:post, search_url).to_return(status: 429, body: "Request rate limited or blocked")

      expect(fast.monthly_ndvi(lat: 40.95, lon: -97.5, months: 6, today: today, threads: 1)).to be_nil
      expect(fast).to be_rate_limited
      # One month, its first try plus RETRY[:max] retries; the other five are never asked.
      expect(search).to have_been_requested.times(described_class::RETRY[:max] + 1)
    end

    it "recovers when the rate limit clears within the retries" do
      fast = described_class.new(cache: ActiveSupport::Cache::MemoryStore.new,
                                 retry_options: described_class::RETRY.merge(interval: 0, interval_randomness: 0))
      empty = { type: "FeatureCollection", features: [] }.to_json
      stub_request(:post, search_url).to_return({ status: 429, body: "slow down" }, { status: 200, body: empty, headers: json })

      expect(fast.monthly_ndvi(lat: 40.95, lon: -97.5, months: 1, today: today, threads: 1)).to eq([ { "month" => "2025-08", "ndvi" => nil } ])
    end
  end

  describe "#terrain" do
    let(:dem_url) { %r{\Ahttps://planetarycomputer\.microsoft\.com/api/data/v1/item/point/} }
    let(:metres_per_degree_lon) { 111_320 * Math.cos(-41.32 * Math::PI / 180) }

    # A plane rising 10 % to the east and 13.3 % to the north: a 16.7 % slope.
    def stub_dem
      stub_request(:get, dem_url).with(query: hash_including("collection" => "nasadem", "expression" => "elevation_b1")).to_return do |req|
        lon, lat = req.uri.path.split("/").last.split(",").map(&:to_f)
        z = 74.0 + ((lon + 72.98) * metres_per_degree_lon * 0.1) + ((lat + 41.32) * 111_320 * (4.0 / 30))
        { status: 200, body: point(z), headers: { "Content-Type" => "application/json" } }
      end
    end

    it "derives elevation and slope from four NASADEM neighbours in the pin's tile" do
      stub = stub_dem

      expect(client.terrain(lat: -41.32, lon: -72.98)).to eq("elevation" => 74.0, "slope" => 16.7)
      expect(stub).to have_been_requested.times(5)
      expect(a_request(:get, dem_url).with(query: hash_including("item" => "NASADEM_HGT_s42w073"))).to have_been_made.times(5)
    end

    it "is empty over open sea and outside the radar's latitudes" do
      stub_request(:get, dem_url).to_return(status: 404, body: "Not Found")

      expect(client.terrain(lat: 0.5, lon: -29.5)).to eq({})
      expect(client.terrain(lat: 70.0, lon: 25.0)).to eq({})
    end

    it "returns nil with the error when the data API fails" do
      fast = described_class.new(cache: ActiveSupport::Cache::MemoryStore.new,
                                 retry_options: described_class::RETRY.merge(interval: 0, interval_randomness: 0))
      stub_request(:get, dem_url).to_return(status: 503, body: "busy")

      expect(fast.terrain(lat: -41.32, lon: -72.98)).to be_nil
      expect(fast.last_error).to include(type: :api_error, status: 503)
    end
  end
end
