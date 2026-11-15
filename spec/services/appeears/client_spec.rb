require "rails_helper"

RSpec.describe Appeears::Client do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:client) { described_class.new(cache: cache) }
  let(:base) { "https://appeears.earthdatacloud.nasa.gov/api" }
  let(:json) { { "Content-Type" => "application/json" } }

  before do
    allow(described_class).to receive(:configured?).and_return(true)
    allow(Rails.application.credentials).to receive_messages(EARTHDATA_USERNAME: "someone", EARTHDATA_PASSWORD: "secret")
  end

  def stub_login(token: "tok-1")
    stub_request(:post, "#{base}/login").with(basic_auth: %w[someone secret])
      .to_return(status: 200, headers: json, body: { token_type: "Bearer", token: token, expiration: 2.days.from_now.iso8601 }.to_json)
  end

  it "logs in once, submits a point task and keeps the token for the next call" do
    login = stub_login
    task = stub_request(:post, "#{base}/task").with(headers: { "Authorization" => "Bearer tok-1" }) { |req|
      body = JSON.parse(req.body)
      body["task_type"] == "point" && body.dig("params", "dates", 0) == { "startDate" => "11-01-2025", "endDate" => "10-31-2026" } &&
        body.dig("params", "coordinates", 0) == { "id" => "field-7", "latitude" => -33.5975, "longitude" => -70.7 }
    }.to_return(status: 202, headers: json, body: { task_id: "abc", status: "pending" }.to_json)
    stub_request(:get, "#{base}/task/abc").to_return(status: 200, headers: json, body: { status: "processing" }.to_json)

    id = client.submit_point(name: "t", layers: [ { product: "SPL4SMGP.008", layer: "Geophysical_Data_sm_rootzone" } ],
                             from: Date.new(2025, 11, 1), to: Date.new(2026, 10, 31), latitude: -33.5975, longitude: -70.7, id: "field-7")

    expect(id).to eq("abc")
    expect(described_class.new(cache: cache).status("abc")).to eq("processing")
    expect(login).to have_been_requested.once
    expect(task).to have_been_requested
  end

  it "logs in again when the token was revoked" do
    stub_login(token: "tok-2")
    cache.write(described_class::TOKEN_KEY, "old")
    stub_request(:get, "#{base}/task/abc").with(headers: { "Authorization" => "Bearer old" }).to_return(status: 401, body: "")
    stub_request(:get, "#{base}/task/abc").with(headers: { "Authorization" => "Bearer tok-2" })
      .to_return(status: 200, headers: json, body: { status: "done" }.to_json)

    expect(client.status("abc")).to eq("done")
  end

  it "downloads the product's results CSV from the bundle, following the redirect" do
    stub_login
    stub_request(:get, "#{base}/bundle/abc").to_return(status: 200, headers: json, body: { files: [
      { file_id: "f1", file_name: "aluni-SPL4SMGP-008-results.csv" }, { file_id: "f2", file_name: "aluni-request.json" }
    ] }.to_json)
    stub_request(:get, "#{base}/bundle/abc/f1").to_return(status: 302, headers: { "Location" => "https://data.example/f1.csv" })
    stub_request(:get, "https://data.example/f1.csv").to_return(status: 200, body: "ID,Date\nfield-7,2026-01-01\n")

    expect(client.results_csv("abc", product: "SPL4SMGP.008")).to eq("ID,Date\nfield-7,2026-01-01\n")

    stub_request(:get, "#{base}/bundle/eco").to_return(status: 200, headers: json, body: { files: [
      { file_id: "e1", file_name: "aluni-ECO-L4T-ESI-002-results.csv" } ] }.to_json)
    stub_request(:get, "#{base}/bundle/eco/e1").to_return(status: 200, body: "ID,Date\n")
    expect(client.results_csv("eco", product: "ECO_L4T_ESI.002")).to eq("ID,Date\n") # underscores become dashes too
  end

  it "raises the data source error when the login fails or the credentials are missing" do
    stub_request(:post, "#{base}/login").to_return(status: 401, body: "bad")
    expect { client.status("abc") }.to raise_error(DataSources::Client::Error, /login failed \(401\)/)

    allow(described_class).to receive(:configured?).and_return(false)
    expect { described_class.new(cache: ActiveSupport::Cache::MemoryStore.new).status("abc") }.to raise_error(DataSources::Client::Error, /credentials are missing/)
  end
end
