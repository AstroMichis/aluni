require "rails_helper"

RSpec.describe Meteomatics::Client do
  let(:client) { described_class.new(username: "user", password: "secret", cache: ActiveSupport::Cache::MemoryStore.new) }
  let(:endpoint) { %r{\Ahttps://api\.meteomatics\.com/.+/t_2m:C,precip_1h:mm/40\.95,-97\.5/json\z} }
  let(:params) { %w[t_2m:C precip_1h:mm] }

  def body
    {
      version: "3.0", status: "OK",
      data: [
        { parameter: "t_2m:C", coordinates: [ { lat: 40.95, lon: -97.5, dates: [ { date: "2026-11-15T12:00:00Z", value: 8.4 }, { date: "2026-11-15T13:00:00Z", value: 9.1 } ] } ] },
        { parameter: "precip_1h:mm", coordinates: [ { lat: 40.95, lon: -97.5, dates: [ { date: "2026-11-15T12:00:00Z", value: 0.0 }, { date: "2026-11-15T13:00:00Z", value: 0.2 } ] } ] }
      ]
    }.to_json
  end

  it "returns a time series per parameter, with basic auth" do
    stub = stub_request(:get, endpoint).with(basic_auth: %w[user secret])
                                       .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })

    result = client.forecast(lat: 40.95, lon: -97.5, hours: 24, parameters: params)

    expect(result.keys).to eq(params)
    expect(result["t_2m:C"].first).to eq([ Time.utc(2026, 11, 15, 12), 8.4 ])
    expect(result["precip_1h:mm"].last.last).to eq(0.2)
    expect(stub).to have_been_requested
  end

  it "builds the window from the current hour" do
    travel_to Time.utc(2026, 11, 15, 12, 34) do
      stub = stub_request(:get, "https://api.meteomatics.com/2026-11-15T12:00:00Z--2026-11-16T12:00:00Z:PT1H/t_2m:C,precip_1h:mm/40.95,-97.5/json")
               .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })

      client.forecast(lat: 40.95, lon: -97.5, hours: 24, parameters: params)
      expect(stub).to have_been_requested
    end
  end

  it "serves a repeated query from the cache" do
    stub = stub_request(:get, endpoint).to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })

    2.times { client.forecast(lat: 40.95, lon: -97.5, hours: 24, parameters: params) }

    expect(stub).to have_been_requested.once
  end

  it "returns nil with an unauthorized error on 401 and does not cache it" do
    stub = stub_request(:get, endpoint).to_return(status: 401, body: "bad login")

    2.times { expect(client.forecast(lat: 40.95, lon: -97.5, hours: 24, parameters: params)).to be_nil }

    expect(client.last_error).to include(type: :unauthorized, status: 401)
    expect(stub).to have_been_requested.twice
  end

  it "rejects more parameters than one query allows" do
    expect(client.forecast(lat: 1, lon: 1, parameters: Array.new(11) { |i| "p#{i}:x" })).to be_nil
    expect(client.last_error[:type]).to eq(:invalid_request)
  end

  it "does not call out without credentials" do
    blank = described_class.new(username: "", password: "", cache: ActiveSupport::Cache::MemoryStore.new)

    expect(blank.forecast(lat: 40.95, lon: -97.5, parameters: params)).to be_nil
    expect(blank.last_error[:type]).to eq(:not_configured)
  end

  it "refuses to call while the service is paused" do
    create(:platform_switch, service: "meteomatics", paused: true)

    expect { client.forecast(lat: 40.95, lon: -97.5, parameters: params) }.to raise_error(Platform::ServicePaused)
  end
end
