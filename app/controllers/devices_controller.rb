# The public catalogue page for the field station (Sonda / Probe): product,
# sensors, offline behaviour, security and specs. Informational only; nothing
# is sold or collected here.
class DevicesController < ApplicationController
  allow_unauthenticated_access
  layout "public"

  MODELS = %w[lite pro].freeze
  SENSORS = %w[soil_moisture soil_temperature air rain light expansion].freeze
  OFFLINE_STEPS = %w[measure store send confirm].freeze
  SECURITY_ITEMS = %w[identity pairing signed updates revoke].freeze
  HIGHLIGHTS = %w[autonomy offline secure install].freeze
  SPEC_ROWS = %w[connectivity location sensors interval storage power security enclosure].freeze

  def show
  end
end
