# frozen_string_literal: true

# Outside APIs are off for the whole suite unless an example opts in:
#
#   it "parses the answer", :gemini_api do ... end
#   it "finds the town", :geocoding_api do ... end
#   (also :meteomatics_api, :planetary_computer_api and :appeears_api)
#
# Files whose subject IS a client (spec/services/<client>/ below)
# are tagged by path. After each example, every HTTP request WebMock saw
# (stubbed or not) is inspected; the suite fails at the end if any reached a
# host the example was not tagged for. Declared after webmock/rspec so this
# `after` runs before WebMock resets its registry.
module ExternalApiCallCounter
  HOSTS = {
    gemini_api: /(?:\A|\.)googleapis\.com\z/,
    geocoding_api: /(?:\A|\.)openstreetmap\.org\z/,
    meteomatics_api: /(?:\A|\.)meteomatics\.com\z/,
    planetary_computer_api: /(?:\A|\.)planetarycomputer\.microsoft\.com\z/,
    appeears_api: /(?:\A|\.)appeears\.earthdatacloud\.nasa\.gov\z/
  }.freeze
  @calls = []

  class << self
    attr_reader :calls

    def collect!(example)
      WebMock::RequestRegistry.instance.requested_signatures.hash.each_key do |signature|
        HOSTS.each do |tag, host|
          next if example.metadata[tag]
          next unless host.match?(signature.uri.host.to_s)

          @calls << "#{example.location} #{signature.method.upcase} #{signature.uri.host}#{signature.uri.path}"
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{spec/services/gemini/}) do |meta|
    meta[:gemini_api] = true unless meta.key?(:gemini_api)
  end
  config.define_derived_metadata(file_path: %r{spec/services/geocoding/}) do |meta|
    meta[:geocoding_api] = true unless meta.key?(:geocoding_api)
  end

  config.define_derived_metadata(file_path: %r{spec/services/meteomatics/}) do |meta|
    meta[:meteomatics_api] = true unless meta.key?(:meteomatics_api)
  end

  config.define_derived_metadata(file_path: %r{spec/services/planetary_computer/}) do |meta|
    meta[:planetary_computer_api] = true unless meta.key?(:planetary_computer_api)
  end

  config.define_derived_metadata(file_path: %r{spec/services/appeears/}) do |meta|
    meta[:appeears_api] = true unless meta.key?(:appeears_api)
  end

  config.after do |example|
    ExternalApiCallCounter.collect!(example)
  end

  config.after(:suite) do
    next if ExternalApiCallCounter.calls.empty?

    sample = ExternalApiCallCounter.calls.uniq.first(5).join("\n  ")
    raise "#{ExternalApiCallCounter.calls.size} outside HTTP call(s) were attempted without the matching tag:\n  #{sample}"
  end
end
