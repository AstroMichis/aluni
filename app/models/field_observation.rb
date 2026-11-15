# What one public data source returned for a field's pin (see
# Fields::FetchObservationsJob). The payload keeps the source's own values;
# Fields::Profile names the paths the screens read.
class FieldObservation < ApplicationRecord
  SOURCES = %w[fcc nasa_power gaez ssurgo usgs_elevation cdl vegetation nasadem gpm_imerg smap].freeze

  belongs_to :field

  # pending: an asynchronous source (AppEEARS) has the request and has not answered yet.
  enum :status, { ok: 0, pending: 5, empty: 10, out_of_coverage: 20, failed: 30 }

  validates :source, inclusion: { in: SOURCES }, uniqueness: { scope: :field_id }
end
