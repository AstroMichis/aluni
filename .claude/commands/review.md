# /review -- Code Review & Quality Audit

You are reviewing code for Aluni. The target is: $ARGUMENTS

Read every file in scope, then check EVERY item below. Report issues by severity: **CRITICAL** > **WARNING** > **SUGGESTION**, each with file, line, what is wrong and how to fix it.

## i18n
- [ ] No visible text outside `t()` in views (`spec/i18n/core_copy_rules_spec.rb` would fail)
- [ ] Every key present in `en` and `es` with the same structure
- [ ] Lazy lookup used correctly in partials and controllers
- [ ] `l()` for dates and times; USD currency formats; `one:`/`other:` where counts appear
- [ ] No em dashes; neutral Spanish; short sentences

## CSS / design system
- [ ] Tokens only (`var(--color-*)`, `var(--space-*)`, `var(--text-*)`, radius, transitions, shadows)
- [ ] Font roles respected (sans UI, serif landing display only, mono numbers)
- [ ] BEM consistent; no inline styles; no utility frameworks
- [ ] Mobile first (`min-width` queries only); dark default and light checked
- [ ] `:focus-visible` ring with `forced-colors` fallback; hover states; 48 px targets
- [ ] `@starting-style` enter animations; `transform`/`opacity` only; `prefers-reduced-motion` respected
- [ ] One `stylesheet_link_tag` per file in the right layout; `native.css` hides web chrome in the shells

## Backend
- [ ] Business logic in services with `Result`; `step` and `try_external` used; controllers thin and pattern matching
- [ ] `format.html` and `format.turbo_stream` where forms submit; `:unprocessable_content` and `:see_other` statuses
- [ ] Model structure order; integer enums; `null: false`; no Float money; `encrypts` on sensitive columns
- [ ] Named keyword arguments; no `params`/`session`/`Current.user` inside services
- [ ] Explicit error handling; no bare `rescue`; logs with a `[ClassName]` prefix
- [ ] Jobs: primitive args, listed queue, cron entries in UTC, switchboard aware (`QUEUE_SERVICES` updated for a new outside service)
- [ ] Messages through `NotificationRouter`; outside calls through a client with `Platform::Switchboard.guard!`

## Authentication and native
- [ ] Authenticated screens inherit `App::BaseController` (session + Pundit + the NativeOnly kill switch); public pages use `allow_unauthenticated_access` and `layout "public"`
- [ ] JSON for native screens inherits `Api::V1::BaseController` (`X-Aluni-Native` on writes)
- [ ] Queries scoped to `Current.user` (`Current.user.things.find(...)`), never `Thing.find(params[:id])`
- [ ] No passwords, no secrets in sessions; the passkey ceremony code stays in `PasskeyCeremony` and the three auth controllers
- [ ] Path configuration rules updated in `ConfigurationsController` when a new modal or native screen appears

## Hotwire / Stimulus
- [ ] Turbo Frames and Streams used for partial updates; custom stream actions only when needed
- [ ] Native `<dialog>` for modals; Stimulus never owns server state; every listener/observer/timer removed in `disconnect()`
- [ ] Vendored libraries only (`vendor/javascript`), lazy `await import()` for heavy ones; CSP unchanged (no new hosts)
- [ ] Preferences honoured: new motion checks go through `reducedMotion()` (`preferences/motion`), new Aluni lines carry `data-speak` and dispatch `speech:read`, nothing is read from `localStorage` for a preference, anything that sets `inert` restores it in `disconnect()`
- [ ] Chat turns: Gemini inline only inside `Onboarding::ReplyService`; a fetch that expects a Turbo Stream renders it whatever the status; `Platform::ServicePaused` rescued in the service, never left to the controller's redirect; nothing from the model saved before the confirm card

## Security
- [ ] No credentials or keys in code; nothing read from `.env*`, `master.key`, `credentials*`
- [ ] Strong parameters; CSRF on (except `ActionController::API` controllers with the header rule); no `html_safe`/`raw` on user input; parameterized SQL
- [ ] Rack::Attack throttle for any new public endpoint; webhook signatures verified with `secure_compare`; body caps
- [ ] File uploads validated (type, size); libvips untrusted loaders blocked

## Rust (`vendor/gems/aluni_core`)
- [ ] Plain data across the boundary; no DB, no credentials, no rendering
- [ ] No `unsafe` without a reviewed comment; no `unwrap()` on Ruby data; `Err(magnus::Error)` not panics
- [ ] A Ruby service wraps the function and rescues `ArgumentError, RuntimeError, AluniCore::Error`
- [ ] `cargo fmt`, `clippy -D warnings`, `cargo test` pass (`bin/rails core:check`); the Ruby oracle spec still exists

## Performance
- [ ] N+1 handled with `includes`/`preload`; indexes for queried columns
- [ ] Heavy work in jobs; session-like state encrypted at rest (`encrypts`) or behind a Redis TTL
- [ ] `contain: layout style` on repeated DOM; variants instead of full-size images

## Tests
- [ ] Specs for new and changed code; success and failure paths; outside APIs stubbed
- [ ] Request specs render pages and assert content; gated paths tested as a browser and with `native_headers`, and once with `with_native_web_access(false)` when the switch matters
- [ ] Factories used; edge cases covered; suite green (`mise exec -- bundle exec rspec`)
