# frozen_string_literal: true

# Service, job and request specs can write Success(value) / Failure(error)
# instead of Result::Success.new(value) / Result::Failure.new(error).
RSpec.configure do |config|
  config.include Result::Mixin, type: :service
  config.include Result::Mixin, type: :job
  config.include Result::Mixin, type: :request
end
