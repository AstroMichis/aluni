# One parcel: a pin (the only input every data source needs), an area, how it
# is watered, and what the farmer knows about the soil in ECOCROP classes.
# The boundary (GeoJSON) waits for a map in a later phase.
class Field < ApplicationRecord
  NAME_MAX = 100
  SOIL = {
    "texture" => %w[heavy medium light organic],
    "depth" => %w[shallow medium deep],
    "drainage" => %w[poor well excessive],
    "salinity" => %w[low medium high],
    "fertility" => %w[low moderate high],
    "problems" => %w[wet_spots compaction erosion crusting weeds pests]
  }.freeze
  # Free-form soil keys the allowlist accepts with any value.
  SOIL_SCALARS = %w[ph lab_test notes].freeze

  belongs_to :farm
  has_many :field_crops, -> { order(season_year: :desc, role: :asc) }, dependent: :destroy
  has_many :observations, class_name: "FieldObservation", dependent: :destroy

  enum :location_confidence, { unknown: 0, approximate: 10, confirmed: 20 }, prefix: true
  enum :location_source, { unknown: 0, geolocation: 10, typed: 20, assistant: 30, map: 40 }, prefix: true
  enum :area_unit, { hectares: 0, acres: 10 }, prefix: true
  enum :irrigation, { unknown: 0, rainfed: 10, irrigated: 20, drip: 30, sprinkler: 40, pivot: 50, gravity: 60, other: 70 }, prefix: true
  enum :water_source, { unknown: 0, rain: 10, well: 20, river_canal: 30, reservoir: 40, mixed: 50 }, prefix: true
  enum :cropping_intensity, { unknown: 0, one_per_year: 10, two_per_year: 20, continuous: 30 }, prefix: true

  validates :name, length: { maximum: NAME_MAX }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validates :place_label, length: { maximum: NAME_MAX }, allow_nil: true
  validates :area, numericality: { greater_than: 0 }, allow_nil: true
  validates :soil, json_allowlist: { keys: SOIL, extra_keys: SOIL_SCALARS }

  # A new or moved pin refreshes what the public data sources say about it.
  after_commit :fetch_observations, if: -> { located? && (saved_change_to_latitude? || saved_change_to_longitude?) }

  def located? = latitude.present? && longitude.present?

  def observation(source) = observations.find { |o| o.source == source.to_s }

  # The row a single-crop writer (the field finder, the chat, the field form)
  # may update for a season: the crop's own row, else the season's only row
  # when the field is not split, else a new row on an empty season. On a
  # season split into zones it never takes another crop's row: nil.
  def season_slot(year, role, crop_key = nil)
    rows = field_crops.select { |c| c.season_year == year.to_i && c.role == role.to_s }
    own = crop_key && rows.find { |c| c.crop_key == crop_key }
    return own if own
    return field_crops.build(season_year: year, role: role) if rows.empty?

    rows.size == 1 && rows.first.whole_field? ? rows.first : nil
  end

  # Anything but "unknown" and "rainfed" means water is applied.
  def uses_irrigation? = !(irrigation_unknown? || irrigation_rainfed?)

  private

  def fetch_observations = Fields::FetchObservationsJob.perform_later(id)
end
