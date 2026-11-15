require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Aluni
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # i18n: English first, Spanish available. Locale files live in nested
    # directories (config/locales/<locale>/**), hence the glob.
    config.i18n.default_locale = :en
    config.i18n.available_locales = [ :en, :es ]
    config.i18n.fallbacks = true
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.yml")]

    # Stored and displayed in UTC; per-user zones can come later.
    config.time_zone = "UTC"

    # Background jobs run on Sidekiq. Every queue a job declares must be listed
    # in config/sidekiq.yml or its jobs are enqueued and never run.
    config.active_job.queue_adapter = :sidekiq

    # Local Redis for development and test. Every app on this machine that
    # started from the same template defaults to database 1, so a shared number
    # makes Sidekiq pick up another project's jobs; aluni keeps its own (7 in
    # development, 8 in test). REDIS_URL and the production credentials are
    # resolved in config/initializers/redis.rb, rack_attack.rb and cable.yml.
    config.x.local_redis_url = "redis://localhost:6379/#{Rails.env.test? ? 8 : 7}"

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
