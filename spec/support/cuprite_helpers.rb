# frozen_string_literal: true

# Cuprite (headless Chrome) for system specs. js_errors: true makes any
# uncaught JavaScript exception fail the example. Each system spec calls
# `driven_by(:cuprite)`.
require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size:     [ 1280, 800 ],
    headless:        true,
    timeout:         15,
    process_timeout: 30,
    js_errors:       true,
    browser_options: { "no-sandbox" => nil }
  )
end

module ServerLogHelpers
  RAILS_LOG_ERROR_PATTERN = /(?:^[A-Z][A-Za-z]+Error|ERROR|FATAL|Internal Server Error)/

  # Tails log/test.log between calls and fails if the delta contains
  # ERROR/FATAL/exception-class lines. The first call within an example seeds
  # the offset, so only entries written DURING the test are checked.
  def expect_no_server_errors!
    log_path = Rails.root.join("log", "#{Rails.env}.log")
    return unless log_path.exist?

    size = log_path.size
    @_server_log_offset ||= size

    if size > @_server_log_offset
      delta = File.open(log_path, "rb") do |f|
        f.seek(@_server_log_offset)
        f.read(size - @_server_log_offset)
      end
      offenders = delta.each_line.select { |line| line.match?(RAILS_LOG_ERROR_PATTERN) }

      unless offenders.empty?
        @_server_log_offset = size
        raise(
          RSpec::Expectations::ExpectationNotMetError,
          "Server log errors since last check (#{offenders.length} line(s)):\n" +
            offenders.first(20).map { |l| "  #{l.chomp}" }.join("\n")
        )
      end
    end

    @_server_log_offset = size
  end
end

RSpec.configure do |config|
  config.include ServerLogHelpers, type: :system
end
