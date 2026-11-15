# frozen_string_literal: true

module Ssurgo
  # USDA Soil Data Access (docs/data_sources/ssurgo.md): the soil survey map
  # unit at a point, its dominant major component and that component's
  # topsoil horizon. United States only; values are survey estimates.
  class Client < DataSources::Client
    BASE_URL = "https://sdmdataaccess.sc.egov.usda.gov/"
    NUMBERS = %w[comppct_r slope_r om_r sandtotal_r claytotal_r awc_r ph1to1h2o_r].freeze

    # { "muname" => "...", "compname" => "Clarion", "drainagecl" => "Well drained", "om_r" => 3.5, ... } or {} outside the survey.
    def soil(latitude:, longitude:)
      sql = <<~SQL
        SELECT mu.muname, c.compname, c.comppct_r, c.hydgrp, c.drainagecl, c.slope_r,
               h.om_r, h.sandtotal_r, h.claytotal_r, h.awc_r, h.ph1to1h2o_r
        FROM SDA_Get_Mukey_from_intersection_with_WktWgs84('point(#{longitude.to_f} #{latitude.to_f})') k
        JOIN mapunit mu ON mu.mukey = k.mukey
        JOIN component c ON c.mukey = mu.mukey AND c.majcompflag = 'Yes'
        LEFT JOIN chorizon h ON h.cokey = c.cokey AND h.hzdept_r = 0
        ORDER BY c.comppct_r DESC
      SQL
      header, first = Array(post_json("Tabular/post.rest", query: sql, format: "JSON+COLUMNNAME")["Table"])
      return {} unless header && first

      header.zip(first).to_h.compact_blank.to_h { |k, v| [ k, NUMBERS.include?(k) ? Float(v, exception: false) : v ] }
    end
  end
end
