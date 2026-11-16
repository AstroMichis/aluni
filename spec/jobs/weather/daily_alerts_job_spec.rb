require "rails_helper"

RSpec.describe Weather::DailyAlertsJob do
  let(:user) { create(:user, locale: "es") }
  let!(:record) { create_farm_for(user) }

  def day(date, tmin: 10.0, tmax: 25.0, rain: 0.0, soil: 8.0)
    Weather::Forecast::Day.new(date: date, tmin: tmin, tmax: tmax, rain: rain, soil_tmin: soil, gust: 3.0)
  end

  def forecast(days) = instance_double(Weather::Forecast, any?: true, days: days)

  before { user.farmer_profile.update!(notification_preferences: { "weather" => %w[frost dry_spell] }) }

  it "sends one alert per field, day and kind the farmer chose, once" do
    today = Date.current
    allow(Weather::Forecast).to receive(:for).and_return(
      forecast([ day(today, tmin: -2.0, soil: -0.5), day(today + 1, tmax: 36.0, rain: 3.0), day(today + 2, tmin: -4.0) ])
    )

    expect { 2.times { described_class.perform_now } }.to change(NotificationDelivery, :count).by(1)

    delivery = NotificationDelivery.last
    expect(delivery).to have_attributes(purpose: "weather_alert", recipient: user,
                                        idempotency_key: "weather:#{record.id}:#{today.iso8601}:frost")
    expect(described_class.parse_key(delivery.idempotency_key)).to eq([ record.id, today, "frost" ]) # heat not chosen, day 3 too far
  end

  it "warns of a dry spell when the next six days bring almost no rain" do
    allow(Weather::Forecast).to receive(:for).and_return(forecast(Array.new(7) { |i| day(Date.current + i, rain: 0.2) }))

    described_class.perform_now

    expect(NotificationDelivery.pluck(:idempotency_key)).to eq([ "weather:#{record.id}:#{Date.current.iso8601}:dry_spell" ])
  end

  it "leaves farmers who chose nothing alone" do
    user.farmer_profile.update!(notification_preferences: {})
    allow(Weather::Forecast).to receive(:for)

    described_class.perform_now

    expect(Weather::Forecast).not_to have_received(:for)
  end

  it "says when to scout for tar spot while the weather suits it, once per run" do
    travel_to Date.new(2025, 7, 20) do
      user.farmer_profile.update!(notification_preferences: { "weather" => %w[scout] })
      allow(Weather::Forecast).to receive(:for).and_return(forecast([]))
      days = (Date.new(2025, 5, 1)..Date.current).map { |d| Weather::Season::Day.new(date: d, tmin: 15, tmean: 20, tmax: 25, rain: 0, wetness: 0.4) }
      allow(Weather::Season).to receive(:for).and_return(Weather::Season.new(days))
      allow(Weather::ScoutWindows).to receive(:for).and_wrap_original { |m, season, _crops| m.call(season, %w[zea-mays]) }

      expect { 2.times { described_class.perform_now } }.to change(NotificationDelivery, :count).by(1)
      expect(NotificationDelivery.last.idempotency_key).to eq("weather:#{record.id}:2025-06-15:scout")
    end
  end
end
