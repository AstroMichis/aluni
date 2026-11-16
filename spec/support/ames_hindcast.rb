# The Ames, Iowa pin of docs/proposal/validation (tracked data): the app's
# services checked against the hindcast's own numbers.
module AmesHindcast
  DATA = Rails.root.join("docs/proposal/validation/data/ames")

  def ames_season(year = 2025)
    p = JSON.parse(File.read(DATA.join("power_daily.json"))).dig("properties", "parameter")
    days = p["T2M"].keys.select { |k| k.start_with?(year.to_s) }.sort.map do |k|
      Weather::Season::Day.new(date: Date.strptime(k, "%Y%m%d"), tmin: p["T2M_MIN"][k], tmean: p["T2M"][k], tmax: p["T2M_MAX"][k],
                               rain: p.dig("PRECTOTCORR", k).to_f, wetness: p.dig("GWETROOT", k).to_f)
    end
    Weather::Season.new(days)
  end

  def ames_imerg_months
    daily = JSON.parse(File.read(DATA.join("imerg_daily.json"))).dig("properties", "parameter", "IMERG_PRECTOT")
    Weather::RainExtremes.summarize(daily)["months"].map { |m| m["rain_mm"].to_f }
  end
end

RSpec.configure { |config| config.include AmesHindcast }
