require "vcr"

# VCR is wired through WebMock for the day a cassette is worth recording; the
# suite stubs outside calls with WebMock directly (spec/services/gemini).
VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  config.ignore_localhost = true
  config.ignore_hosts "chromedriver.storage.googleapis.com",
                      "googlechromelabs.github.io",
                      "storage.googleapis.com"

  { "<GEMINI_KEY>" => [ :gemini, :api_key ] }.each do |placeholder, path|
    config.filter_sensitive_data(placeholder) do
      Rails.application.credentials.dig(*path)
    end
  end
end
