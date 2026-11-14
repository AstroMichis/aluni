# Every example ends on the real clock, whatever travel_to / freeze_time it used.
RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
  config.after { travel_back }
end
