# frozen_string_literal: true

module Fields
  # The NASA products a field's pin gets through AppEEARS, which answers
  # asynchronously: the first run submits a point task for one source and
  # keeps its observation pending with the task id; later runs poll it every
  # POLL_WAIT and, when the task is done, read the product's results CSV into
  # that source's summary. One task per source, so a slow product (a year of
  # 3-hourly SMAP takes about 45 minutes) never holds the others.
  #
  #   smap       SMAP L4 root-zone soil moisture, last 12 months (Weather::SoilMoisture)
  #   modis      MODIS NDVI every 16 days since 2001, its 20-year normal (Fields::VegetationNormal)
  #   ecostress  ECOSTRESS evaporative stress index, last 3 years (Weather::WaterStress)
  #
  # Enqueued per source by Fields::FetchObservationsJob; a paused `data` switch
  # holds it like the other sources (ApplicationJob).
  class FetchAppeearsJob < ApplicationJob
    queue_as :default

    Source = Struct.new(:product, :layers, :summary, keyword_init: true) do
      def window = summary.window
      def summarize(csv) = summary.summarize(csv)
    end

    def self.sources
      @sources ||= {
        "smap" => Source.new(product: "SPL4SMGP.008", layers: %w[Geophysical_Data_sm_rootzone Geophysical_Data_sm_rootzone_pctl],
                             summary: Weather::SoilMoisture),
        "modis" => Source.new(product: "MOD13Q1.061", layers: %w[_250m_16_days_NDVI _250m_16_days_pixel_reliability],
                              summary: Fields::VegetationNormal),
        "ecostress" => Source.new(product: "ECO_L4T_ESI.002", layers: %w[ESI cloud], summary: Weather::WaterStress)
      }.freeze
    end

    FIRST_WAIT = 5.minutes
    POLL_WAIT = 5.minutes
    MAX_POLLS = 36 # three hours

    def perform(field_id, source: "smap", task_id: nil, polls: 0)
      @field = Field.find_by(id: field_id)
      @source = source.to_s
      @config = self.class.sources[@source]
      return unless @field&.located? && @config
      return mark(:empty, {}, "Earthdata credentials are not configured") unless Appeears::Client.configured?

      task_id ? poll(task_id, polls) : submit
    rescue DataSources::Client::Error => e
      Rails.logger.warn("[#{self.class.name}] #{@source} for field #{field_id}: #{e.message}")
      mark(:failed, {}, e.message)
    end

    private

    def submit
      from, to = @config.window
      task_id = client.submit_point(name: "aluni-field-#{@field.id}-#{@source}", layers: @config.layers.map { |l| { product: @config.product, layer: l } },
                                    from: from, to: to, latitude: @field.latitude, longitude: @field.longitude, id: "field-#{@field.id}")
      mark(:pending, { "task_id" => task_id })
      later(FIRST_WAIT, task_id: task_id, polls: 1)
    end

    def poll(task_id, polls)
      # A newer pin or refresh started another task: this one is stale.
      return unless observation&.pending? && observation.payload["task_id"] == task_id

      case client.status(task_id)
      when Appeears::Client::DONE
        summary = @config.summarize(client.results_csv(task_id, product: @config.product))
        mark(summary.present? ? :ok : :empty, summary)
      when Appeears::Client::FAILED
        mark(:failed, {}, "AppEEARS task #{task_id} failed")
      else
        return mark(:failed, {}, "AppEEARS task #{task_id} still running after #{polls} checks") if polls >= MAX_POLLS

        later(POLL_WAIT, task_id: task_id, polls: polls + 1)
      end
    end

    # Always this class: the SMAP-only subclass below exists for jobs queued before it.
    def later(wait, **args) = FetchAppeearsJob.set(wait: wait).perform_later(@field.id, source: @source, **args)

    def observation = (@observation ||= @field.observations.find_by(source: @source))
    def client = (@client ||= Appeears::Client.new)

    def mark(status, payload, error = nil)
      record = @field.observations.find_or_initialize_by(source: @source)
      record.update!(status: status, payload: payload, error: error, fetched_at: Time.current)
    end
  end
end
