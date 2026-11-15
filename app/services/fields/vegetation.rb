# frozen_string_literal: true

module Fields
  # Reads a field's monthly NDVI (the "vegetation" observation: Landsat and
  # Sentinel-2 through PlanetaryComputer::Client#monthly_ndvi) into what the
  # screens and the rotation plan say about the ground cover:
  #
  # - each month as bare (soil showing), sparse or green;
  # - bare periods: runs of consecutive bare months, the windows where a cover
  #   crop could protect the soil;
  # - the greenest month.
  #
  # Thresholds are the usual reading of NDVI for cropland: under 0.25 is
  # mostly bare soil or stubble, over 0.45 a closed, growing canopy. A month
  # without a clear view stays unknown and breaks a run. One pixel at the pin,
  # 10 to 30 m: it describes that spot of the field.
  class Vegetation
    BARE = 0.25
    GREEN = 0.45
    SOURCE = "Landsat (NASA/USGS) · Sentinel-2 (ESA)"

    Month = Struct.new(:month, :ndvi, :cover, :mission, :date, keyword_init: true) do
      def label_date = Date.strptime(month, "%Y-%m")
      def known? = !ndvi.nil?
    end
    Period = Struct.new(:from, :to, :months, keyword_init: true)

    def initialize(observation)
      @payload = observation&.ok? ? observation.payload.to_h : {}
    end

    def present? = months.any?(&:known?)

    def months
      @months ||= Array(@payload["months"]).map do |row|
        ndvi = row["ndvi"]&.to_f
        Month.new(month: row["month"], ndvi: ndvi, cover: cover(ndvi), mission: row["mission"], date: row["date"])
      end
    end

    def known_months = months.select(&:known?)

    # Runs of consecutive bare months, oldest first.
    def bare_periods
      @bare_periods ||= months.chunk_while { |a, b| a.cover == "bare" && b.cover == "bare" }
                              .select { |run| run.first.cover == "bare" }
                              .map { |run| Period.new(from: run.first.label_date, to: run.last.label_date, months: run.size) }
    end

    def bare_months = months.count { |m| m.cover == "bare" }
    def longest_bare = bare_periods.max_by(&:months)
    def greenest = known_months.max_by(&:ndvi)
    def missions = known_months.filter_map(&:mission).uniq

    private

    def cover(ndvi)
      return if ndvi.nil?
      return "bare" if ndvi < BARE

      ndvi < GREEN ? "sparse" : "green"
    end
  end
end
