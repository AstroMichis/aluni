# One crop in one season on one field: the history the rotation advice reads.
# crop_key is a slug of the scientific name (falling back to the common name)
# so the same crop typed in two languages matches one record later.
#
# A season may split the field between crops (crop zones): share is the part
# of the field the crop covers (0 to 1, the area's source of truth) and cells
# where it sits on the 10x10 field map (Fields::CellLayout). No share and no
# cells means the whole field.
class FieldCrop < ApplicationRecord
  NAME_MAX = 100
  YEARS = 1900...2200
  GRID_SIDE = 10
  GRID = GRID_SIDE * GRID_SIDE
  # A harvest is recorded in the farmer's own units: an amount per hectare or
  # per acre, the price per that amount and the cost per that area, so the
  # margin needs no bushel weights. HECTARE turns a per-acre figure per hectare.
  YIELD_UNITS = %w[t kg bu qq].freeze
  AREA_BASES = %w[ha ac].freeze
  CURRENCIES = %w[USD EUR MXN BRL ARS CLP COP PEN CAD GBP].freeze
  ACRES_PER_HECTARE = 2.4710538

  belongs_to :field

  enum :role, { main: 0, second: 10, cover: 20, intercrop: 30 }, prefix: true
  enum :source, { farmer: 0, cdl: 10, assistant: 20 }, prefix: true

  before_validation :assign_crop_key

  validates :crop_name, presence: true, length: { maximum: NAME_MAX }
  validates :scientific_name, length: { maximum: NAME_MAX }, allow_nil: true
  validates :season_year, numericality: { only_integer: true }, inclusion: { in: YEARS }
  validates :planting_month, :harvest_month, inclusion: { in: 1..12 }, allow_nil: true
  validates :crop_key, uniqueness: { scope: %i[field_id season_year role] }
  validates :notes, length: { maximum: 500 }, allow_nil: true
  validates :share, numericality: { greater_than: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validate :cells_on_the_map
  validates :yield_amount, :price, :cost, numericality: { greater_than_or_equal_to: 0, less_than: 10**9 }, allow_nil: true
  validates :yield_unit, inclusion: { in: YIELD_UNITS }, allow_nil: true
  validates :area_basis, inclusion: { in: AREA_BASES }, allow_nil: true
  validates :currency, inclusion: { in: CURRENCIES }, allow_nil: true
  validates :yield_unit, :area_basis, presence: true, if: :yield_amount
  validates :currency, presence: true, if: -> { price || cost }
  validate :harvest_in_the_past

  def self.key_for(crop_name, scientific_name = nil) = (scientific_name.presence || crop_name).to_s.parameterize.presence

  def whole_field? = share.nil?

  # The part of the field it covers: 1 for the whole field.
  def portion = share&.to_f || 1.0

  # The map cells it covers: every cell for the whole field.
  def map_cells = whole_field? ? (0...GRID).to_a : cells

  def harvest? = yield_amount.present?

  # Income less costs per hectare in the record's currency, or nil without a yield and a price.
  def margin_per_ha
    return nil unless yield_amount && price

    per_area = (yield_amount * price) - cost.to_d
    (area_basis == "ac" ? per_area * ACRES_PER_HECTARE : per_area).to_f
  end

  private

  def harvest_in_the_past
    return unless (yield_amount || price || cost) && season_year.to_i > Date.current.year

    errors.add(:season_year, :invalid)
  end

  def cells_on_the_map
    errors.add(:cells, :invalid) if cells.any? { |c| !c.is_a?(Integer) || !(0...GRID).cover?(c) } || cells.uniq.size != cells.size
    errors.add(:cells, :blank) if share && cells.empty?
    errors.add(:share, :blank) if share.nil? && cells.any?
  end

  def assign_crop_key
    self.crop_key = self.class.key_for(crop_name, scientific_name)
  end
end
