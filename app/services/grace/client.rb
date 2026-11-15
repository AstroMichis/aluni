# frozen_string_literal: true

require "zlib"

module Grace
  # The monthly water storage anomaly at a point from NASA's GRACE and
  # GRACE-FO satellites (JPL RL06.3 v04 mascons with the CRI filter,
  # docs/data_sources/grace.md): liquid water equivalent thickness in cm
  # against the 2004.0-2009.999 mean, times the grid's land scale factor.
  # 0.5° grid, 3° mascons: a region about 300 km wide, never the farm alone.
  #
  # The whole series is one 44 MB netCDF behind Earthdata Login, and PO.DAAC's
  # OPeNDAP cannot subset it (no DMR++ for the file). PO.DAAC publishes an open
  # reference file (kerchunk) with the byte range of every compressed chunk, so
  # only the four lwe_thickness chunks that hold the cell (66 months x 90 x 180
  # each, zlib) and one scale-factor chunk are read with HTTP Range requests.
  class Client
    REFS_URL = "https://archive.podaac.earthdata.nasa.gov/podaac-ops-cumulus-public/virtual_collections/" \
               "TELLUS_GRAC-GRFO_MASCON_CRI_GRID_RL06.3_V4/TELLUS_GRAC-GRFO_MASCON_CRI_GRID_RL06.3_V4_virtual_https.json"
    REFS_KEY = "grace/refs/v1"
    EPOCH = Date.new(2002, 1, 1) # time is "days since 2002-01-01"
    FILL = -99_999.0

    Error = DataSources::Client::Error

    def initialize(cache: Rails.cache)
      @cache = cache
    end

    # [[Date, cm], ...] oldest first, or [] where the cell has no land value.
    def series(latitude:, longitude:)
      lat_i = ((latitude.to_f + 89.75) / 0.5).round.clamp(0, 359)
      lon_i = (((longitude.to_f % 360) - 0.25) / 0.5).round.clamp(0, 719)
      dates = times
      t_chunk, y_chunk, x_chunk = chunks("lwe_thickness")
      values = (0...(dates.size.to_f / t_chunk).ceil).flat_map do |tc|
        raw = chunk("lwe_thickness/#{tc}.#{lat_i / y_chunk}.#{lon_i / x_chunk}")
        plane = y_chunk * x_chunk
        offset = ((lat_i % y_chunk) * x_chunk) + (lon_i % x_chunk)
        (0...(raw.bytesize / (plane * 8))).map { |k| raw[((k * plane) + offset) * 8, 8].unpack1("E") }
      end
      scale = chunk("scale_factor/0.0.0")[((lat_i * 720) + lon_i) * 8, 8].unpack1("E")
      return [] if scale.nil? || scale <= FILL

      dates.zip(values).filter_map { |date, cm| [ date, (cm * scale).round(2) ] if cm && cm > FILL }
    end

    private

    def refs
      @refs ||= @cache.fetch(REFS_KEY, expires_in: 1.day) do
        response = request { follow(http.get(REFS_URL)) }
        raise Error, "#{self.class.name}: references unavailable (#{response.status})" unless response.success?

        JSON.parse(response.body).fetch("refs")
      end
    end

    def times
      refs.fetch("time/0").delete_prefix("base64:").unpack1("m").unpack("E*").map { |days| EPOCH + days.floor }
    end

    def chunks(variable) = JSON.parse(refs.fetch("#{variable}/.zarray")).fetch("chunks")

    # A chunk's bytes, inflated.
    def chunk(key)
      url, offset, length = refs.fetch(key) { raise Error, "#{self.class.name}: no chunk #{key}" }
      range = "bytes=#{offset}-#{offset + length - 1}"
      response = request { follow(http.get(url) { |r| r.headers["Authorization"] = "Bearer #{Earthdata::Token.fetch(cache: @cache)}"; r.headers["Range"] = range }, range) }
      raise Error, "#{self.class.name}: #{key} (#{response.status})" unless [ 200, 206 ].include?(response.status)

      Zlib::Inflate.inflate(response.body)
    rescue Zlib::Error => e
      raise Error, "#{self.class.name}: #{key} #{e.message}"
    end

    # PO.DAAC answers with redirects to a signed S3 URL; the Range goes along, the token does not.
    def follow(response, range = nil)
      3.times do
        break unless response.status.between?(300, 399)

        response = http.get(response.headers["location"]) { |r| r.headers["Range"] = range if range }
      end
      response
    end

    def request
      Platform::Switchboard.guard!(:data)
      yield
    rescue Faraday::Error => e
      raise Error, "#{self.class.name}: #{e.class.name.demodulize} #{e.message}".truncate(250)
    end

    def http = (@http ||= Faraday.new { |f| f.options.timeout = 60; f.options.open_timeout = 10 })
  end
end
