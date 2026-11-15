# frozen_string_literal: true

module Appeears
  # The results CSV AppEEARS returns for one product of a point task, read
  # without the csv gem (a separate gem since Ruby 3.4; these files are plain).
  # Columns are found by suffix, because AppEEARS prefixes them with the
  # product and version (SPL4SMGP_008_Geophysical_Data_sm_rootzone,
  # MOD13Q1_061__250m_16_days_NDVI, ECO_L4T_ESI_002_ESI) and adds grid columns
  # whose names carry the resolution.
  module Csv
    module_function

    # [{ at: Time, "<suffix>" => Float or nil, ... }] for the rows with a date,
    # oldest first. `columns` maps a key to the column-name suffix it reads.
    def rows(text, columns)
      lines = text.to_s.lines.map { |line| fields(line.chomp) }
      headers = lines.shift.to_a
      date = headers.index("Date")
      index = columns.transform_values { |suffix| headers.index { |h| h.end_with?(suffix) } }
      return [] unless date && index.values.all?

      lines.filter_map do |row|
        at = (Time.zone.parse(row[date].to_s) rescue nil) or next
        index.each_with_object({ at: at }) { |(key, i), out| out[key] = Float(row[i].to_s, exception: false) }
      end.sort_by { |r| r[:at] }
    end

    # One CSV line into its fields, honouring double quotes.
    def fields(line)
      out = [ +"" ]
      quoted = false
      chars = line.chars
      i = 0
      while i < chars.size
        c = chars[i]
        if c == '"' && quoted && chars[i + 1] == '"' then out.last << '"'; i += 1
        elsif c == '"' then quoted = !quoted
        elsif c == "," && !quoted then out << +""
        else out.last << c
        end
        i += 1
      end
      out
    end
  end
end
