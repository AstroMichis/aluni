# This file is copied to spec/ when you run 'rails generate rspec:install'
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"

# Support files: driver registration, auth helpers, the external-API guard, VCR.
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

# Ensures that the test database schema matches the current schema file.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true

  config.include FactoryBot::Syntax::Methods
  config.include ActiveJob::TestHelper

  # spec/requests => type: :request, spec/models => type: :model, and so on.
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# No real HTTP from the suite. Cuprite talks to Chrome on localhost.
WebMock.disable_net_connect!(allow_localhost: true)
