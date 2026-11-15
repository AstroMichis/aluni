module App
  # Weather (menu section 3): the season so far and the long-term normals at
  # a field's pin (NASA POWER), and the alerts it would have raised.
  class WeatherController < BaseController
    include FarmScreen

    before_action do
      @field = selected_field
      @season = Weather::Season.for(@field&.observation("nasa_power"))
    end

    def show
    end

    def alerts
    end

    def update_alerts
      save_and_return Weather::AlertsService.call(user: Current.user, alerts: params[:alerts]), fallback: alerts_app_weather_path
    end
  end
end
