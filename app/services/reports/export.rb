# frozen_string_literal: true

module Reports
  # Everything the farm holds, to take away: every datum of the farm and each
  # field with its state, value, source and confidence, plus the plan, team
  # and tasks. JSON keeps the structure; CSV is one row per datum.
  class Export
    COLUMNS = %w[subject datum state value source scale confidence].freeze

    def initialize(farm, profile:)
      @farm = farm
      @profile = profile
    end

    def filename(extension) = "farm-#{Date.current.iso8601}.#{extension}"

    def rows
      [ @farm, *@farm.fields ].flat_map do |subject|
        subject.readings.map do |r|
          { "subject" => subject.key, "datum" => r.datum.key, "state" => r.state.to_s, "value" => r.known? ? flat(r.values) : nil,
            "source" => r.source&.name, "scale" => r.known? ? r.scale : nil, "confidence" => r.known? ? r.confidence : nil }
        end
      end
    end

    def to_json(*)
      JSON.pretty_generate("generated_on" => Date.current.iso8601, "sample" => @farm.sample?, "location" => @farm.location,
                           "readings" => rows, "plans" => @farm.plans, "team" => @farm.team, "tasks" => @farm.tasks)
    end

    # RFC 4180: fields with a comma, quote or line break are quoted, quotes doubled.
    def to_csv
      ([ COLUMNS ] + rows.map { |row| row.values_at(*COLUMNS) }).map { |line| line.map { |cell| quote(cell) }.join(",") }.join("\r\n") + "\r\n"
    end

    private

    def flat(values)
      values.size == 1 ? Array(values.values.first).join("; ") : values.map { |k, v| "#{k}=#{v}" }.join("; ")
    end

    def quote(cell)
      text = cell.to_s
      text.match?(/[",\r\n]/) ? %("#{text.gsub('"', '""')}") : text
    end
  end
end
