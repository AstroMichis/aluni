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

  def self.key_for(crop_name, scientific_name = nil) = (scientific_name.presence || crop_name).to_s.parameterize.presence

  def whole_field? = share.nil?

  # The part of the field it covers: 1 for the whole field.
  def portion = share&.to_f || 1.0

  # The map cells it covers: every cell for the whole field.
  def map_cells = whole_field? ? (0...GRID).to_a : cells

  private

  def cells_on_the_map
    errors.add(:cells, :invalid) if cells.any? { |c| !c.is_a?(Integer) || !(0...GRID).cover?(c) } || cells.uniq.size != cells.size
    errors.add(:cells, :blank) if share && cells.empty?
    errors.add(:share, :blank) if share.nil? && cells.any?
  end

  def assign_crop_key
    self.crop_key = self.class.key_for(crop_name, scientific_name)
  end
end
