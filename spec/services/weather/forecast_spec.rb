require "rails_helper"

RSpec.describe Weather::Forecast do
  # Two whole local days at longitude -70.7 (UTC-5 by the sun) and a few hours of a third.
  let(:start) { Time.utc(2026, 11, 16, 5) }
  let(:hours) { 52 }

  def series(**overrides)
    base = {
      "t_2m:C" => ->(i) { i < 24 ? 8.0 + (i % 24) / 2.0 : -1.5 + (i % 24) / 3.0 },
      "precip_1h:mm" => ->(i) { i.between?(30, 35) ? 5.0 : 0.0 },
      "prob_precip_1h:p" => ->(i) { i.between?(30, 35) ? 80.0 : 5.0 },
      "wind_gusts_10m_1h:ms" => ->(i) { i == 40 ? 18.0 : 4.0 },
      "evapotranspiration_1h:mm" => ->(_) { 0.2 },
      "soil_moisture_index_-15cm:idx" => ->(_) { 0.55 },
      "t_-5cm:C" => ->(i) { 6.0 + (i % 24) / 4.0 }
    }.merge(overrides)
    base.transform_values { |f| Array.new(hours) { |i| [ start + i.hours, f.call(i) ] } }
  end

  it "sums the hours into local solar days" do
    forecast = described_class.new(series, longitude: -70.7)

    expect(forecast.days.map(&:date)).to eq([ Date.new(2026, 11, 16), Date.new(2026, 11, 17) ]) # the 4 hours of the 18th are left out
    first, second = forecast.days
    expect([ first.tmin, first.tmax, first.rain, first.et ]).to eq([ 8.0, 19.5, 0.0, 4.8 ])
    expect([ second.tmin, second.rain, second.rain_chance, second.gust, second.soil_moisture ]).to eq([ -1.5, 30.0, 80.0, 18.0, 0.55 ])
  end

  it "raises the day's alerts and the week's water balance" do
    forecast = described_class.new(series, longitude: -70.7)

    expect(forecast.days.first.alerts).to be_empty
    expect(forecast.days.last.alerts).to eq(%w[frost heavy_rain wind])
    expect(forecast.alerts.map { |day, kind| [ day.date.day, kind ] }).to eq([ [ 17, "frost" ], [ 17, "heavy_rain" ], [ 17, "wind" ] ])
    expect(forecast.balance).to eq(30 - 10) # 30 mm of rain against 48 h x 0.2 mm
  end

  it "explains why there is no forecast" do
    field = instance_double(Fields::Farm::Field, located?: true, record: build(:field, latitude: -33.6, longitude: -70.7))
    client = instance_double(Meteomatics::Client, forecast: nil, last_error: { type: :rate_limited })
    allow(Meteomatics::Client).to receive(:configured?).and_return(true)

    expect(described_class.for(field, client: client).error).to eq(:rate_limited)
    expect(described_class.for(nil).error).to eq(:needs_pin)
    allow(Meteomatics::Client).to receive(:configured?).and_return(false)
    expect(described_class.for(field, client: client)).to have_attributes(error: :not_configured, any?: false)
  end
end
