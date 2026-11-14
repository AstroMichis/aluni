# CLAUDE.md

## What is this

Aluni is an open source tool for people, not for passwords. The web site at aluni.us is informational; the product lives in the iOS and Android apps (Hotwire Native shells around this Rails app), where people sign in with a passkey (face, fingerprint or device code) and never see a username or a password. Bilingual English/Spanish, English first. Dark-first design. The product domain is defined separately from this infrastructure; nothing here assumes it.

## Critical rules

- **Ruby only through mise.** `mise exec -- bin/rails ...`, `mise exec -- bundle exec rspec`. Never bare `ruby`, `rails` or `bundle`.
- **Passkeys only.** No passwords, no Devise, no JWT. Sign-in is a WebAuthn ceremony (`docs/AUTH.md`); sessions are rows (`Session`) behind a permanent signed cookie.
- **The web is informational.** Sign-in, sign-up, passkeys and `/app` answer only to the native shells (`NativeOnly`); `NATIVE_WEB_ACCESS=1` opens them to browsers in development.
- **Pure CSS only.** No Tailwind, no Bootstrap, no bundler, no node. CSS custom properties + BEM; one `stylesheet_link_tag` per file.
- **Hotwire, not SPA.** Turbo + Stimulus. Heavy libraries (Three.js) are vendored and loaded lazily with `await import()`.
- **Service objects for business logic.** `ApplicationService` + `Result`; controllers pattern match; models hold validations and associations only.
- **Rust lives only in `vendor/gems/aluni_core`.** Ruby services (`app/services/core/`) are the only callers; Rust never touches the database. Rebuild with `bin/rails core:compile`.
- **Every UI string through `t()`.** Default locale `:en`, `:es` available, parity enforced by specs. No em dashes in copy.
- **Mobile-first, dark-first.** `min-width` media queries; `:root` is the dark theme.
- **Outside services go through the switchboard.** Clients call `Platform::Switchboard.guard!(:service)`; the operator pauses with `platform:*` rake tasks.
- **Messages go through `NotificationRouter`**, never a mailer or a push sender directly.
- **Never read `.env*`, `config/master.key`, `config/credentials*` or `.kamal/secrets`.** Never start servers, install packages or spawn browsers unprompted. The operator runs git.
- **Specs render pages** (assert on body content), and the suite runs before anything is called done.

## Tech stack

| Layer | Technology |
|-------|-----------|
| Backend | Ruby on Rails 8.1, Ruby 4.0.8 (mise.toml + .ruby-version) |
| Database | PostgreSQL 16, Active Record encryption with a boot guard |
| Cache/Queue | Redis 7 + Sidekiq 8 + sidekiq-cron (queues in config/sidekiq.yml) |
| Auth | Rails 8 built-in sessions + webauthn gem (passkeys) |
| Frontend | Hotwire (Turbo + Stimulus), pure CSS, importmap-rails, vendored Three.js r169 |
| Native | Hotwire Native iOS 1.2 (ios/, XcodeGen) and Android 1.2 (android/, Gradle KTS) |
| Rust | vendor/gems/aluni_core (magnus 0.9 on rb-sys 0.9, Rust 1.92 via rust-toolchain.toml) |
| AI | Google Gemini over Faraday (`Gemini::Client`), paused by default on first deploy |
| Push | action_push_native (APNs/FCM) + web-push (VAPID) behind `NotificationRouter` |
| Storage | Cloudflare R2 (S3 adapter) via Active Storage, proxied through the app |
| Hosting | Oracle Always Free A1 VM via Kamal 2 + GHCR + GitHub Actions (config/deploy.yml, docs/deploy/DEPLOY.md) |
| Cost control | Operator pause switches for jobs/cron/gemini/mail/push (app/services/platform/, `platform:*` rake, GitHub workflow) |
| Fonts | Inter (UI), Fraunces (display), JetBrains Mono (numbers); placeholders, swap in base/variables.css |

## Documentation map

Read the relevant doc before working on that area:

| File | When to read |
|------|-------------|
| `docs/AUTH.md` | Sign-in, sign-up, passkeys, sessions, the native gate, dev setup for WebAuthn |
| `docs/NATIVE.md` | The iOS and Android shells, path configuration, app links, bridge components, building them |
| `docs/DESIGN_SYSTEM.md` | Any UI work: tokens, typography, CSS components, layouts, the Three.js hero |
| `docs/DATA_MODEL.md` | Tables, migrations, associations, conventions |
| `docs/RAILS_PATTERNS.md` | Service objects, controllers, Hotwire, Stimulus, jobs, the switchboard |
| `docs/I18N.md` | Locale files, switching, formats, the copy specs |
| `docs/INTEGRATIONS.md` | Gemini, push, web push, mail, R2, outbound client and inbound webhook shapes |
| `docs/RUST.md` | The extension gem: rules, dev loop, CI and Docker steps |
| `docs/INFRASTRUCTURE.md` | Gemfile, routes, ENV and credentials inventory, testing, CI |
| `docs/deploy/DEPLOY.md` | Setting up and running production for $0 |

Builder skills live in `.claude/commands/` (`/service`, `/job`, `/model`, `/stimulus`, `/ui`, `/i18n`, `/test`, `/review`, `/gemini`, `/auth`, `/rust`, `/ios`, `/android`, `/build`); `.claude/skills/verify` says how to verify without node tooling.

## Project structure

```
app/
  assets/stylesheets/       # base/ components/ layouts/ pages/ utilities/ native.css (docs/DESIGN_SYSTEM.md)
  controllers/
    app/                     # Authenticated area (native shells): App::BaseController
    api/v1/                  # JSON for native screens (session cookie + X-Aluni-Native header)
    concerns/                # Authentication, NativeOnly, PasskeyCeremony
    sessions_controller.rb   # Passkey sign-in
    registrations_controller.rb  # Passkey sign-up
    passkeys_controller.rb   # Add/remove passkeys
    pages_controller.rb      # Informational site + locale switch
    configurations_controller.rb, app_links_controller.rb  # Native shell endpoints
  javascript/controllers/    # Stimulus (passkey, hero_scene, theme, toast, bridge/*)
  jobs/                      # ApplicationJob (switchboard aware), sessions/, notifications/
  mailers/                   # ApplicationMailer, NotificationMailer
  models/                    # User, Session, Passkey, PlatformSwitch, DeviceToken, WebPushSubscription, NotificationDelivery, Result
  services/
    application_service.rb   # Result + step + try_external
    core/                    # Ruby wrappers around the Rust extension
    gemini/                  # Gemini client + language lock
    notifications/           # Router channels, purposes registry, push devices
    platform/                # Switchboard, toggle, cron control, features
  views/
    layouts/                 # public.html.erb (site), application.html.erb (app), mailer
    pages/ sessions/ registrations/ passkeys/ app/home/ shared/ pwa/
config/
  locales/{en,es}/           # Nested locale trees (parity enforced by spec/i18n)
  initializers/              # app_domain, redis, sidekiq, rack_attack, csp, webauthn, native, gemini, ...
  native_app.yml, notification_purposes.yml, sidekiq.yml, sidekiq_cron.yml, deploy.yml
ios/  android/               # Hotwire Native shells (docs/NATIVE.md)
vendor/gems/aluni_core/      # Rust extension (docs/RUST.md)
vendor/javascript/           # three.js, hotwire-native-bridge (vendored)
spec/                        # RSpec: requests render pages; i18n/ enforces copy rules; system/ uses Cuprite
```
