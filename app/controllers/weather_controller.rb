# Weather (section 3): the season so far at the farm's point, and the alerts
# it would have raised, with which ones the person wants.
class WeatherController < ApplicationController
  include FarmPreview

  before_action { @season = Weather::Season.load }

  def show
  end

  def alerts
  end

  def update_alerts
    save_and_return Weather::AlertsService.call(data: draft.data, alerts: params[:alerts]), fallback: alerts_menu_weather_path
  end
end
