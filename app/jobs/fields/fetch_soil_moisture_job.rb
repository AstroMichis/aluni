# frozen_string_literal: true

module Fields
  # NASA SMAP soil moisture at a field's pin over the last year, through
  # AppEEARS, which answers asynchronously: the first run submits a point task
  # and keeps the "smap" observation pending with its id; later runs poll it
  # every POLL_WAIT and, when the task is done, read the results CSV into
  # Weather::SoilMoisture's summary. Enqueued by Fields::FetchObservationsJob;
  # a paused `data` switch holds it like the other sources (ApplicationJob).
  class FetchSoilMoistureJob < ApplicationJob
    queue_as :default

    SOURCE = "smap"
    PRODUCT = "SPL4SMGP.008"
    LAYERS = [ { product: PRODUCT, layer: "Geophysical_Data_sm_rootzone" },
               { product: PRODUCT, layer: "Geophysical_Data_sm_rootzone_pctl" } ].freeze
    FIRST_WAIT = 5.minutes
    POLL_WAIT = 5.minutes
    MAX_POLLS = 36 # three hours; AppEEARS usually answers in 2 to 30 minutes

    def perform(field_id, task_id: nil, polls: 0)
      @field = Field.find_by(id: field_id)
      return unless @field&.located?
      return mark(:empty, {}, "Earthdata credentials are not configured") unless Appeears::Client.configured?

      task_id ? poll(task_id, polls) : submit
    rescue DataSources::Client::Error => e
      Rails.logger.warn("[#{self.class.name}] field #{field_id}: #{e.message}")
      mark(:failed, {}, e.message)
    end

    private

    def submit
      from, to = Weather::SoilMoisture.window
      task_id = client.submit_point(name: "aluni-field-#{@field.id}-smap", layers: LAYERS, from: from, to: to,
                                    latitude: @field.latitude, longitude: @field.longitude, id: "field-#{@field.id}")
      mark(:pending, { "task_id" => task_id })
      self.class.set(wait: FIRST_WAIT).perform_later(@field.id, task_id: task_id, polls: 1)
    end

    def poll(task_id, polls)
      # A newer pin or refresh started another task: this one is stale.
      return unless observation&.pending? && observation.payload["task_id"] == task_id

      case client.status(task_id)
      when Appeears::Client::DONE
        summary = Weather::SoilMoisture.summarize(client.results_csv(task_id, product: PRODUCT))
        mark(summary.present? ? :ok : :empty, summary)
      when Appeears::Client::FAILED
        mark(:failed, {}, "AppEEARS task #{task_id} failed")
      else
        return mark(:failed, {}, "AppEEARS task #{task_id} still running after #{polls} checks") if polls >= MAX_POLLS

        self.class.set(wait: POLL_WAIT).perform_later(@field.id, task_id: task_id, polls: polls + 1)
      end
    end

    def observation = (@observation ||= @field.observations.find_by(source: SOURCE))
    def client = (@client ||= Appeears::Client.new)

    def mark(status, payload, error = nil)
      record = @field.observations.find_or_initialize_by(source: SOURCE)
      record.update!(status: status, payload: payload, error: error, fetched_at: Time.current)
    end
  end
end
