source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.1.4"
gem "pg", "~> 1.5"
gem "puma", "~> 7.2", ">= 7.2.1"
gem "redis", "~> 5.0"
gem "sidekiq", "~> 8.1"
gem "sidekiq-cron", "~> 2.4"

# Authentication: passkeys only (WebAuthn); sessions through Rails 8 built-in authentication.
gem "webauthn", "~> 3.5", ">= 3.5.1"

# Frontend: Hotwire over importmap, no bundler, no node.
gem "turbo-rails", "~> 2.0"
gem "stimulus-rails", "~> 1.3"
gem "propshaft"
gem "importmap-rails"

# Storage: Cloudflare R2 through the S3 adapter; variants through libvips.
gem "aws-sdk-s3", "~> 1.0"
gem "image_processing", "~> 1.12"

# HTTP clients (Gemini and any other outside service).
gem "faraday", "~> 2.9"
gem "faraday-retry", "~> 2.2"

# The season report as a PDF (Reports::Pdf): pure Ruby, no system packages or browser.
gem "prawn", "~> 2.5"
gem "prawn-table", "~> 0.2"

# Authorization.
gem "pundit", "~> 2.4"

# Request security.
gem "rack-attack", "~> 6.7"

# i18n.
gem "rails-i18n", "~> 8.0"

# Push notifications: APNs/FCM and Web Push.
gem "action_push_native", "~> 0.3"
gem "web-push", "~> 3.1"

# Rust extension build helper (vendor/gems/aluni_core).
# rake-compiler provides the compile task rb_sys/extensiontask builds on (dev, CI and the Docker build stage).
gem "rb_sys", "~> 0.9"
gem "rake-compiler", require: false
gem "aluni_core", path: "vendor/gems/aluni_core"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "dotenv-rails"
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails"
  gem "faker"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "shoulda-matchers"
  gem "webmock"
  gem "vcr"
  gem "capybara"
  gem "cuprite"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  gem "kamal", require: false
end
