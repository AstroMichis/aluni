require "rails_helper"

RSpec.describe Geocoding::Client, type: :service do
  let(:client) { described_class.new }
  let(:json) { { "Content-Type" => "application/json; charset=utf-8" } }
  let(:ames) do
    {
      "lat" => "42.0307812", "lon" => "-93.6319131", "name" => "Ames",
      "display_name" => "Ames, Story County, Iowa, United States",
      "address" => { "city" => "Ames", "county" => "Story County", "state" => "Iowa", "country" => "United States", "country_code" => "us" }
    }
  end

  def stub_search(query, locale: "en", **options)
    stub = stub_request(:get, "https://nominatim.openstreetmap.org/search")
      .with(query: { "q" => query, "format" => "jsonv2", "limit" => "5", "addressdetails" => "1", "accept-language" => locale },
            headers: { "User-Agent" => "Aluni/1.0 (+https://aluni.us)" })
    options.any? ? stub.to_return(**options) : stub
  end

  def stub_reverse(lat, lon, locale: "en", **options)
    stub = stub_request(:get, "https://nominatim.openstreetmap.org/reverse")
      .with(query: { "lat" => lat, "lon" => lon, "format" => "jsonv2", "zoom" => "10", "addressdetails" => "1", "accept-language" => locale })
    options.any? ? stub.to_return(**options) : stub
  end

  describe "#search" do
    it "normalises up to five places with the region, the country and a short label" do
      stub = stub_search("Ames, Iowa", status: 200, body: [ ames, { "lat" => "x", "lon" => "y" } ].to_json, headers: json)

      rows = client.search("  Ames,  Iowa ", locale: :en)

      expect(rows).to eq([ {
        label: "Ames, Story County, Iowa, United States", display: "Ames, Iowa",
        latitude: 42.030781, longitude: -93.631913, country_code: "US", country: "United States", admin_area: "Iowa"
      } ])
      expect(client.last_error).to be_nil
      expect(stub).to have_been_requested.once
    end

    it "asks in the given language" do
      stub = stub_search("Bogotá", locale: "es", status: 200, body: [].to_json, headers: json)

      expect(client.search("Bogotá", locale: :es)).to eq([])
      expect(stub).to have_been_requested
    end

    it "answers a blank query without a request" do
      expect(client.search("   ")).to eq([])
      expect(a_request(:get, /nominatim/)).not_to have_been_made
    end

    it "caches an answer for a day, keyed on the normalised query" do
      store = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(store)
      stub = stub_search("Ames", status: 200, body: [ ames ].to_json, headers: json)

      first = client.search("Ames", locale: :en)
      second = described_class.new.search(" ames ", locale: :en)

      expect(second).to eq(first)
      expect(stub).to have_been_requested.once
      expect(store.exist?("geocode/v1/search/en/ames")).to be(true)
    end

    it "does not retry a 429 and reports it" do
      stub = stub_search("Ames", status: 429, body: "", headers: {})

      expect(client.search("Ames")).to be_nil
      expect(client.last_error).to include(type: :rate_limited, status: 429)
      expect(stub).to have_been_requested.once
    end

    it "retries a timeout once, then gives up with nil" do
      stub = stub_search("Ames").to_timeout

      expect(client.search("Ames")).to be_nil
      expect(client.last_error[:type]).to eq(:network_error)
      expect(stub).to have_been_requested.twice
    end

    it "refuses to call while the switch is paused, without raising" do
      create(:platform_switch, service: "geocoding", paused: true)

      expect(client.search("Ames")).to be_nil
      expect(client.last_error).to eq(type: :paused)
      expect(a_request(:get, /nominatim/)).not_to have_been_made
    end

    it "treats a server error and a non-JSON body as failures" do
      stub_search("Ames", status: 500, body: "boom", headers: {})
      expect(client.search("Ames")).to be_nil
      expect(client.last_error).to include(type: :api_error, status: 500)

      stub_search("Nowhere", status: 200, body: "<html></html>", headers: { "Content-Type" => "text/html" })
      expect(client.search("Nowhere")).to be_nil
      expect(client.last_error).to eq(type: :unexpected)
    end
  end

  describe "#reverse" do
    it "names the place around a pin, rounding the coordinates to three decimals" do
      stub = stub_reverse("42.031", "-93.632", status: 200, body: ames.to_json, headers: json)

      place = client.reverse(latitude: 42.0307812, longitude: -93.6319131, locale: :en)

      expect(place).to include(display: "Ames, Iowa", country_code: "US", admin_area: "Iowa", country: "United States")
      expect(stub).to have_been_requested.once
    end

    it "returns nil with not_found for open water" do
      stub_reverse("0.0", "0.0", status: 200, body: { "error" => "Unable to geocode" }.to_json, headers: json)

      expect(client.reverse(latitude: 0, longitude: 0)).to be_nil
      expect(client.last_error).to eq(type: :not_found)
    end

    it "caches by rounded coordinates and language" do
      store = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(store)
      stub = stub_reverse("42.0", "-93.75", locale: "es", status: 200, body: ames.to_json, headers: json)

      client.reverse(latitude: 42.0001, longitude: -93.7504, locale: :es)
      described_class.new.reverse(latitude: 41.9996, longitude: -93.7496, locale: :es)

      expect(stub).to have_been_requested.once
      expect(store.exist?("geocode/v1/reverse/es/42.0/-93.75")).to be(true)
    end
  end
end
