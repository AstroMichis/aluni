# Infrastructure

## Toolchain

| Layer | Pinned where | Value |
|---|---|---|
| Ruby | `mise.toml`, `.ruby-version`, `Dockerfile` `ARG RUBY_VERSION` | 4.0.8 |
| Rails | `Gemfile` | ~> 8.1.4 |
| Rust | `rust-toolchain.toml` (rustup; Homebrew cargo ignores it, must be >= 1.92) | 1.92.0 |
| PostgreSQL / Redis | `config/deploy.yml`, CI services | 16 / 7 |
| Node | none | the app has no JavaScript build step |

Every Ruby command runs through mise: `mise exec -- bin/rails ...`.

## Gemfile (what each gem is for)

rails, pg, puma, redis + sidekiq + sidekiq-cron (jobs, cron, cache, cable), webauthn (passkeys), turbo-rails + stimulus-rails + propshaft + importmap-rails (frontend), aws-sdk-s3 + image_processing (R2 storage, libvips variants), faraday + faraday-retry (outside APIs), pundit (authorization seam in `App::BaseController`), rack-attack, rails-i18n, action_push_native + web-push, rb_sys + aluni_core (Rust extension), bootsnap. Development/test: debug, dotenv-rails, rspec-rails, factory_bot_rails, faker, bundler-audit, brakeman, rubocop-rails-omakase; test: shoulda-matchers, webmock, vcr, capybara, cuprite; development: web-console, kamal.

## Routes skeleton (`config/routes.rb`)

```
/up                                   health (outside every scope, excluded from SSL and host checks)
/configurations/v1/:platform          native shells (declared first)
/.well-known/apple-app-site-association, /.well-known/assetlinks.json
/manifest.json, /service-worker.js    PWA
/api/v1/me                            JSON for native screens
/webhooks/...                         (empty; each provider adds a feature-gated route)
/sidekiq                              only with SIDEKIQ_WEB_* set, on ADMIN_HOST, basic auth
/locale/:new_locale                   locale switch
(/:locale)/                           root: landing page
(/:locale)/sign_in, sign_in/options, sign_out, sign_up, sign_up/options
(/:locale)/passkeys, passkeys/options
(/:locale)/app                        authenticated area (+ device_tokens, web_push_subscriptions)
(/:locale)/app/onboarding             the chat: show, message, confirm, discard, skip, complete (POST), reset (DELETE)
```

`default_url_options` always adds the locale, so every generated link carries `/en/` or `/es/`.

## ENV inventory

| Name | Used by |
|---|---|
| `DATABASE_URL`, `REDIS_URL` | database.yml, redis.rb, cable.yml, rack_attack.rb, production cache. Without `REDIS_URL`, development uses local database 7 and test database 8 (`config.x.local_redis_url` in application.rb) so Sidekiq never shares a database with another app on the machine |
| `RAILS_MASTER_KEY`, `SECRET_KEY_BASE_DUMMY` (build only) | credentials, asset precompile |
| `RAILS_MAX_THREADS`, `SIDEKIQ_CONCURRENCY`, `RAILS_LOG_LEVEL`, `MALLOC_ARENA_MAX`, `RAILS_SERVE_STATIC_FILES`, `PORT`, `PIDFILE` | puma, sidekiq, logging |
| `APP_DOMAIN`, `APP_PORT`, `ADMIN_HOST`, `DEV_HOSTS` | app_domain.rb, hosts, mailer URLs, WebAuthn RP id |
| `TRUSTED_PROXIES` | production.rb (Cloudflare ranges) |
| `NATIVE_WEB_ACCESS` (default on; `0` closes sign-in and `/app` to browsers, shells keep working), `SIGNUPS_ENABLED` | native.rb, Platform::Features |
| `SIDEKIQ_WEB_USERNAME`, `SIDEKIQ_WEB_PASSWORD` | sidekiq_web.rb |
| `PLATFORM_PAUSE_ALL`, `PLATFORM_ACTOR` | switchboard brake, toggle actor |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `..._DETERMINISTIC_KEY`, `..._KEY_DERIVATION_SALT`, `AR_ENCRYPTION_SUPPORT_UNENCRYPTED_DATA` | encryption (alternative to credentials) |
| `GEMINI_FLASH_MODEL`, `GEMINI_PRO_MODEL`, `GEMINI_TRANSCRIBE_MODEL`, `GEMINI_CHAT_MAX_OUTPUT_TOKENS` | gemini.rb |
| `GEMINI_BACKEND` (`api_key` default, `vertex` in production), `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION` (`global`) | gemini.rb, `Gemini::Client.backend`, `Gemini::VertexToken` |
| `ACTIVE_STORAGE_SERVICE` (`cloudflare_r2` or `local`), `KAMAL_BACKUP` (`0` leaves the R2 backup accessory out) | production.rb, deploy.yml |
| `METEOMATICS_USERNAME`, `METEOMATICS_PASSWORD`, `METEOMATICS_CACHE_TTL_SECONDS` | meteomatics.rb, `Meteomatics::Client` (off while unset) |
| `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET` | storage.yml fallbacks, backup accessory |
| `APNS_DEVELOPMENT` | push.yml |
| `MAILER_FROM` | ApplicationMailer fallback |
| `KAMAL_HOST`, `KAMAL_SSH_USER`, `KAMAL_ARCH`, `KAMAL_TUNNEL`, `KAMAL_BUILDER_REMOTE`, `KAMAL_IMAGE`, `KAMAL_REGISTRY_SERVER`, `KAMAL_REGISTRY_USERNAME`, `KAMAL_REGISTRY_PASSWORD`, `KAMAL_KNOWN_HOSTS`, `KAMAL_SSH_KEY` | deploy.yml, deploy workflow |
| `POSTGRES_PASSWORD`, `APP_DB_PASSWORD`, `REDIS_PASSWORD`, `BACKUP_PASSPHRASE`, `TUNNEL_TOKEN`, `CERTIFICATE_PEM`, `PRIVATE_KEY_PEM`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `TS_OAUTH_CLIENT_ID`, `TS_AUDIENCE` | accessories, tunnel, Tailscale |
| `CI` | test.rb eager load |
| `DB_PREPARE_ON_BOOT` | docker-entrypoint |

`.env.example` lists them with comments; `.env` is git-ignored and never read by Claude.

## Credentials keys (`bin/rails credentials:edit`)

`secret_key_base`, `active_record_encryption.{primary_key,deterministic_key,key_derivation_salt}` (or the three `ACTIVE_RECORD_ENCRYPTION_*` Kamal secrets), `gemini.api_key` (only with `GEMINI_BACKEND=api_key`; the Vertex backend needs no key), `meteomatics.{username,password}` (or the `METEOMATICS_*` Kamal secrets), `redis.url`, `production.database_url`, `r2.{account_id,access_key_id,secret_access_key}`, `mailer.from`, `smtp.{address,port,user_name,password,domain}`, `web_push.{public_key,private_key,subject}`, `action_push_native.apns.{key_id,encryption_key,team_id,topic}`, `action_push_native.fcm.{encryption_key,project_id}`, `native_app.{apple_team_id,android_cert_sha256}`.

Every flag an initializer derives from ENV or credentials is exposed on `Rails.configuration.x.*` and read through `Platform::Features`, never from ENV in app code.

## Testing

RSpec (`spec/rails_helper.rb`): WebMock blocks every outside request (`spec/support/external_apis.rb` fails the suite if any request reaches Gemini outside a `:gemini_api` spec), FactoryBot, shoulda-matchers, `ActiveJob::TestHelper` everywhere (test adapter in `config/environments/test.rb`), Cuprite for `spec/system` (headless Chrome, `js_errors: true`), `WebAuthn::FakeClient` for passkey ceremonies, `sign_in_as(user)` and `native_headers` for request specs. `spec/i18n/` enforces locale parity, string keys and the copy rules. Request specs render pages and assert on the body.

```sh
mise exec -- bundle exec rspec
mise exec -- bin/rubocop
mise exec -- bin/brakeman --no-pager
mise exec -- bin/rails core:check
```

## CI (`.github/workflows/ci.yml`)

`test` (Postgres 16 + Redis 7 services, libvips, rustup, bundle, compile the extension, cargo test, schema load, rspec), `security` (brakeman, bundler-audit, cargo audit; weekly and on PRs to main), `lint` (rubocop, cargo fmt, clippy). Every action is pinned by SHA. `.github/dependabot.yml` watches bundler, cargo and actions weekly.

## Deploy

`config/deploy.yml` (Kamal 2), `.kamal/secrets` (names only), `.kamal/hooks/pre-deploy` (migrations once per deploy), `.github/workflows/deploy.yml` (manual or `v*` tags, builds on the arm64 VM), `.github/workflows/platform-switch.yml` (pause/resume services). Runbook: `docs/deploy/DEPLOY.md`.
