# frozen_string_literal: true

module Fields
  # One piece of a field that has carried the same crops: the cells of the
  # field map (FieldCrop::GRID) that share this season's crop, last season's
  # and next season's plan. A field that was never split is one zone of all
  # its cells, so everything that reads a zone reads a whole field the same
  # way. Rotations::Comparator and Rotations::Timeline take a zone: the
  # rotation is followed per piece of ground, not per field.
  #
  # Each season's crop on a zone is the crop most of its cells carried, so an
  # older season split along other lines still reads as one crop.
  class Zone
    GRID = FieldCrop::GRID

    attr_reader :field, :cells, :index

    # What Rotations::Comparator and Rotations::Timeline read besides the crops.
    delegate :record, :observation, :cover_crops, :double_crops, to: :field

    # The field's zones, the largest first; cells with no crop this season
    # come last as a fallow zone.
    def self.for(field)
      crops = field.main_crops
      return [ new(field, (0...GRID).to_a, {}, index: 0) ] if crops.empty?

      by_cell = Array.new(GRID) { {} }
      crops.each { |crop| crop.map_cells.each { |cell| by_cell[cell][crop.season_year] = crop } }
      now = field.current_season
      before = crops.map(&:season_year).select { |y| now && y < now }.max
      plan = Date.current.year + 1
      groups = (0...GRID).group_by { |cell| [ now, before, plan ].map { |y| by_cell[cell][y]&.id } }
      zones = groups.values.map { |cells| [ cells, crops_by_year(cells, by_cell) ] }
      zones.sort_by! { |cells, years| [ years[now] ? 0 : 1, -cells.size, cells.first ] }
      zones.each_with_index.map { |(cells, years), i| new(field, cells, years, index: i) }
    end

    # Season year => the crop most of the cells carried that year.
    def self.crops_by_year(cells, by_cell)
      cells.flat_map { |cell| by_cell[cell].to_a }.group_by(&:first).to_h do |year, pairs|
        [ year, pairs.map(&:last).tally.max_by { |crop, count| [ count, -crop.id ] }.first ]
      end
    end

    def initialize(field, cells, crops_by_year, index:)
      @field = field
      @cells = cells
      @crops_by_year = crops_by_year
      @index = index
    end

    def current_crop = (now = field.current_season) && @crops_by_year[now]
    def plan = @crops_by_year[Date.current.year + 1]
    def fallow? = current_crop.nil? && field.main_crops.any?
    def whole_field? = cells.size == GRID

    # Season year (string) => crop, up to this season, oldest first.
    def history
      @crops_by_year.select { |year, _| year <= Date.current.year }.sort.to_h { |year, crop| [ year.to_s, crop ] }
    end

    # [[label, crop], ...] for Crops::RotationCheck: the seasons, then the plan.
    def seasons
      list = history.to_a
      list << [ "plan", plan ] if plan
      list
    end

    # The part of the field: its crop's own share when the zone is exactly
    # that crop's cells, else its count of cells.
    def share
      crop = current_crop
      return crop.portion if crop && crop.map_cells.sort == cells.sort

      cells.size / GRID.to_f
    end
  end
end
