require "rails_helper"

RSpec.describe Grace::Client do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:data_url) { "https://archive.podaac.earthdata.nasa.gov/podaac-ops-cumulus-protected/grace.nc" }
  let(:signed) { "https://podaac-ops-cumulus-protected.s3.us-west-2.amazonaws.com/grace.nc?X-Amz-Signature=x" }

  # A tiny stand-in for the real file: 3 months in 2 time chunks of 2, 90 x 180 cells per chunk,
  # and one 360 x 720 scale-factor plane; Buin (-33.6, -70.7) is cell [112, 578].
  def plane(months, value_for)
    (0...months).flat_map { |m| Array.new(90 * 180) { |k| k == ((112 % 90) * 180) + (578 % 180) ? value_for.call(m) : -99_999.0 } }
  end

  before do
    allow(Earthdata::Token).to receive(:fetch).and_return("edl-token")
    body = +""
    chunks = {}
    add = lambda do |key, floats|
      bytes = Zlib::Deflate.deflate(floats.pack("E*"))
      chunks[key] = [ data_url, body.bytesize, bytes.bytesize ]
      body << bytes
    end
    add.call("lwe_thickness/0.1.3", plane(2, ->(m) { [ 3.0, -4.0 ][m] }))
    add.call("lwe_thickness/1.1.3", plane(1, ->(_) { -10.0 }))
    scale = Array.new(360 * 720, -99_999.0)
    scale[(112 * 720) + 578] = 1.5
    add.call("scale_factor/0.0.0", scale)
    refs = chunks.merge(
      "lwe_thickness/.zarray" => { chunks: [ 2, 90, 180 ] }.to_json,
      "time/0" => "base64:#{[ [ 15.0, 46.0, 74.0 ].pack("E*") ].pack("m0")}"
    )
    stub_request(:get, described_class::REFS_URL).to_return(status: 303, headers: { "Location" => "https://cdn.example/refs.json" })
    stub_request(:get, "https://cdn.example/refs.json").to_return(status: 200, body: { version: 1, refs: refs }.to_json)
    stub_request(:get, data_url).with(headers: { "Authorization" => "Bearer edl-token" }).to_return do |req|
      { status: 307, headers: { "Location" => signed, "X-Range" => req.headers["Range"] } }
    end
    stub_request(:get, signed).to_return do |req|
      from, to = req.headers["Range"].delete_prefix("bytes=").split("-").map(&:to_i)
      { status: 206, body: body.byteslice(from..to) }
    end
  end

  it "reads only the chunks that hold the cell and scales them" do
    series = described_class.new(cache: cache).series(latitude: -33.5975, longitude: -70.7)

    expect(series).to eq([ [ Date.new(2002, 1, 16), 4.5 ], [ Date.new(2002, 2, 16), -6.0 ], [ Date.new(2002, 3, 16), -15.0 ] ])
    expect(a_request(:get, signed)).to have_been_made.times(3)
  end

  it "has nothing for a cell without the land scale factor (open sea), and says so for a missing chunk" do
    expect(described_class.new(cache: cache).series(latitude: -33.0975, longitude: -70.7)).to eq([]) # cell [113, 578], same chunks
    expect { described_class.new(cache: cache).series(latitude: 40.95, longitude: -97.5) }
      .to raise_error(DataSources::Client::Error, %r{no chunk lwe_thickness/0\.2\.2})
  end
end
