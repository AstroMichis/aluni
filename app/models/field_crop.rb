# One crop in one season on one field: the history the rotation advice reads.
# crop_key is a slug of the scientific name (falling back to the common name)
# so the same crop typed in two languages matches one record later.
class FieldCrop < ApplicationRecord
  NAME_MAX = 100
  YEARS = 1900...2200

  belongs_to :field

  enum :role, { main: 0, second: 10, cover: 20, intercrop: 30 }, prefix: true
  enum :source, { farmer: 0, cdl: 10, assistant: 20 }, prefix: true

  before_validation :assign_crop_key

  validates :crop_name, presence: true, length: { maximum: NAME_MAX }
  validates :scientific_name, length: { maximum: NAME_MAX }, allow_nil: true
  validates :season_year, numericality: { only_integer: true }, inclusion: { in: YEARS }
  validates :planting_month, :harvest_month, inclusion: { in: 1..12 }, allow_nil: true
  validates :role, uniqueness: { scope: %i[field_id season_year] }
  validates :notes, length: { maximum: 500 }, allow_nil: true

  private

  def assign_crop_key
    self.crop_key = (scientific_name.presence || crop_name).to_s.parameterize.presence
  end
end
