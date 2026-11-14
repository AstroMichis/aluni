# frozen_string_literal: true

# Outside APIs are off for the whole suite unless an example opts in:
#
#   it "parses the answer", :gemini_api do ... end
#
# Files whose subject IS the Gemini client (spec/services/gemini/) are tagged
# by path. After each example that ran without the tag, every HTTP request
# WebMock saw (stubbed or not) is inspected; the suite fails at the end if any
# reached a Gemini host. Declared after webmock/rspec so this `after` runs
# before WebMock resets its registry (after hooks run in reverse order).
module ExternalApiCallCounter
  GEMINI_HOST = /(?:\A|\.)googleapis\.com\z/
  @calls = []

  class << self
    attr_reader :calls

    def collect!(example)
      WebMock::RequestRegistry.instance.requested_signatures.hash.each_key do |signature|
        next unless GEMINI_HOST.match?(signature.uri.host.to_s)

        @calls << "#{example.location} #{signature.method.upcase} #{signature.uri.host}#{signature.uri.path}"
      end
    end
  end
end

RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{spec/services/gemini/}) do |meta|
    meta[:gemini_api] = true unless meta.key?(:gemini_api)
  end

  config.after do |example|
    ExternalApiCallCounter.collect!(example) unless example.metadata[:gemini_api]
  end

  config.after(:suite) do
    next if ExternalApiCallCounter.calls.empty?

    sample = ExternalApiCallCounter.calls.uniq.first(5).join("\n  ")
    raise "#{ExternalApiCallCounter.calls.size} Gemini HTTP call(s) were attempted outside :gemini_api specs:\n  #{sample}"
  end
end
