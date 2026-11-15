# frozen_string_literal: true

# WebMock stubs for the public data sources, built from the responses captured
# in docs/data_sources/*.md (spec/fixtures/data_sources/).
module DataSourceStubs
  def data_source_fixture(name) = File.read(Rails.root.join("spec/fixtures/data_sources", name))

  def stub_power(daily: { "T2M" => { "20260101" => -4.1 }, "T2M_MIN" => { "20260101" => -9.0 }, "T2M_MAX" => { "20260101" => 1.2 },
                          "PRECTOTCORR" => { "20260101" => 0.4 }, "GWETROOT" => { "20260101" => 0.47 } })
    stub_request(:get, %r{power\.larc\.nasa\.gov/api/temporal/daily/point}).to_return(
      status: 200, headers: { "Content-Type" => "application/json" }, body: { properties: { parameter: daily } }.to_json)
    stub_request(:get, %r{power\.larc\.nasa\.gov/api/temporal/climatology/point}).to_return(
      status: 200, headers: { "Content-Type" => "application/json" }, body: data_source_fixture("power_climatology.json"))
  end

  def stub_gaez
    stub_request(:get, %r{gaez-services\.fao\.org/.+/query}).to_return(
      status: 200, headers: { "Content-Type" => "application/json" }, body: data_source_fixture("gaez_query.json"))
    stub_request(:get, %r{gaez-services\.fao\.org/.+/identify}).to_return(
      status: 200, headers: { "Content-Type" => "application/json" }, body: data_source_fixture("gaez_identify.json"))
  end

  def stub_fcc(us: true)
    stub_request(:get, %r{geo\.fcc\.gov/api/census/block/find}).to_return(
      status: 200, headers: { "Content-Type" => "application/json" }, body: data_source_fixture(us ? "fcc_us.json" : "fcc_outside.json"))
  end

  def stub_us_layer
    stub_request(:post, %r{sdmdataaccess\.sc\.egov\.usda\.gov/Tabular/post\.rest}).to_return(
      status: 200, headers: { "Content-Type" => "application/json" }, body: data_source_fixture("ssurgo.json"))
    stub_request(:get, %r{epqs\.nationalmap\.gov/v1/json}).to_return(
      status: 200, headers: { "Content-Type" => "application/json" }, body: { value: "321.7" }.to_json)
    # One captured GetCDLValue answer (Corn), returned for whichever year is asked.
    stub_request(:get, %r{nassgeodata\.gmu\.edu/.+/GetCDLValue}).to_return(status: 200, body: data_source_fixture("cdl_get_value.xml"))
  end

  # The monthly NDVI series without HTTP: Planetary Computer requests are only
  # allowed in specs tagged :planetary_computer_api (spec/support/external_apis.rb).
  def stub_vegetation(ndvi = [ 0.1, 0.12, 0.3, 0.6, 0.7, 0.2 ])
    start = Date.current.beginning_of_month << (ndvi.size - 1)
    rows = ndvi.each_with_index.map do |value, i|
      { "month" => (start >> i).strftime("%Y-%m"), "ndvi" => value, "mission" => (value ? "landsat" : nil) }.compact
    end
    allow_any_instance_of(PlanetaryComputer::Client).to receive(:monthly_ndvi).and_return(rows)
  end

  def stub_terrain(terrain = { "elevation" => 74.0, "slope" => 3.2 })
    allow_any_instance_of(PlanetaryComputer::Client).to receive(:terrain).and_return(terrain)
  end

  def stub_all_data_sources(us: true)
    stub_fcc(us: us)
    stub_power
    stub_gaez
    stub_vegetation
    stub_terrain
    stub_us_layer
  end
end

RSpec.configure { |config| config.include DataSourceStubs }
