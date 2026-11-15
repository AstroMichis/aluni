# frozen_string_literal: true

module Weather
  # Every morning (config/sidekiq_cron.yml): for each farmer who chose weather
  # alerts, the next two days of the forecast at each located field
  # (Weather::Forecast, Meteomatics) and one NotificationRouter message per
  # field, day and kind they asked for: frost, heat, heavy rain, or a dry spell
  # (DRY_DAYS days ahead with almost no rain). The idempotency key
  # (weather:<field>:<date>:<kind>) sends each alert once however often the job
  # runs, and the alerts screen lists what was sent from it.
  class DailyAlertsJob < ApplicationJob
    queue_as :default

    PURPOSE = "weather_alert"
    AHEAD = 2        # today and tomorrow, local days at the pin
    DRY_DAYS = 6     # a dry spell: this many forecast days in a row under DRY_MM
    DRY_MM = 1.0

    def self.key(field_id, date, kind) = "weather:#{field_id}:#{date.iso8601}:#{kind}"

    # [field_id, Date, kind] from a delivery's idempotency key, or nil.
    def self.parse_key(key)
      _, field_id, date, kind = key.to_s.split(":")
      [ field_id.to_i, Date.iso8601(date), kind ] if kind
    rescue Date::Error
      nil
    end

    def perform
      FarmerProfile.includes(:user).find_each do |profile|
        kinds = Array(profile.notification_preferences.to_h["weather"]) & Weather::AlertsService::KINDS
        next if kinds.empty? || !profile.user&.onboarding_complete?

        Fields::Farm.for(profile.user).fields.select(&:located?).each { |field| alert(profile.user, field, kinds) }
      end
    end

    private

    def alert(user, field, kinds)
      forecast = Weather::Forecast.for(field)
      return unless forecast.any?

      forecast.days.first(AHEAD).each do |day|
        (day.alerts & kinds).each { |kind| deliver(user, field, day, kind) }
      end
      dry = forecast.days.first(DRY_DAYS)
      return unless kinds.include?("dry_spell") && dry.size == DRY_DAYS && dry.all? { |d| d.rain.to_f < DRY_MM }

      deliver(user, field, dry.first, "dry_spell", days: DRY_DAYS)
    end

    def deliver(user, field, day, kind, days: nil)
      I18n.with_locale(user.locale.presence || I18n.default_locale) do
        name = helpers.plot_name(field)
        kind_label = I18n.t("notifications.weather_alert.kinds.#{kind}")
        when_label = I18n.l(day.date, format: "%A %-d")
        text = I18n.t("notifications.weather_alert.text.#{kind}",
                      tmin: number(day.tmin), tmax: number(day.tmax), soil: number(day.soil_tmin), rain: number(day.rain, 0), days: days)
        path = "/app/weather?field=#{field.record.id}"
        NotificationRouter.deliver(
          recipient: user, purpose: PURPOSE, idempotency_key: self.class.key(field.record.id, day.date, kind),
          payload: {
            group: { field: field.record.id },
            push: { title: { field: name, kind: kind_label }, body: { day: when_label, text: text }, path: path, url: "/#{I18n.locale}#{path}" },
            mailer_args: [ user, I18n.t("notifications.weather_alert.subject", field: name, kind: kind_label, day: when_label), "#{when_label}: #{text}" ]
          }
        )
      end
    end

    def number(value, precision = 1)
      value.nil? ? "–" : ActiveSupport::NumberHelper.number_to_rounded(value, precision: precision, strip_insignificant_zeros: true)
    end

    def helpers = ApplicationController.helpers
  end
end
