# /build -- Full-Stack Feature Builder

You are building a full-stack feature for Aluni. The feature request is: $ARGUMENTS

## Before writing ANY code, do ALL of the following:

1. **Read the project docs** relevant to this feature:
   - `CLAUDE.md` (always; critical rules)
   - `docs/DESIGN_SYSTEM.md` if any UI work
   - `docs/RAILS_PATTERNS.md` if any backend work
   - `docs/I18N.md` if any user-facing strings
   - `docs/INTEGRATIONS.md` if touching Gemini, push, mail or storage
   - `docs/DATA_MODEL.md` if touching models
   - `docs/AUTH.md` if touching sign-in, sessions or the native gate
   - `docs/NATIVE.md` if the screen must behave inside the shells

2. **Analyze existing patterns** by reading at least one example of each layer you will touch:
   - Model: `app/models/passkey.rb` (associations, validations, one `!` method)
   - Service: `app/services/core/normalize_service.rb` and `app/services/platform/toggle_service.rb`
   - Controller: `app/controllers/passkeys_controller.rb` (authenticated, native-only, JSON + HTML) and `app/controllers/app/home_controller.rb`
   - View: `app/views/passkeys/index.html.erb` (card, list, form, Stimulus)
   - Test: `spec/requests/passkey_flow_spec.rb` (request specs that render pages)
   - CSS: `app/assets/stylesheets/components/card.css`, `pages/app.css`
   - Stimulus: `app/javascript/controllers/toast_controller.js` (simple), `passkey_controller.js` (fetch + feedback)
   - Locale: `config/locales/en/en.yml` and the relevant `config/locales/en/views/en.<area>.yml`

3. **Present a build plan** to the user before writing code. List:
   - Files to create (in order)
   - Files to modify
   - Migration(s) needed
   - i18n keys needed (both en and es)
   - Any new routes, and whether they are native-only (`App::` namespace) or public

## Build order (always follow this sequence):

### Step 1: Database
- `mise exec -- bin/rails generate migration ...` (never hand-written files)
- Conventions in `docs/DATA_MODEL.md`: `null: false`, integer enums with defaults, jsonb defaults, no Float money
- `mise exec -- bin/rails db:migrate`

### Step 2: Model
- `mise exec -- bin/rails generate model ...` for a new model (rspec and factory files come with it)
- Structure order: associations -> enums -> encrypts -> scopes -> validations -> callbacks -> public methods -> private methods
- `encrypts :field` for sensitive columns; add the model to `ENCRYPTED_MODELS` in `lib/tasks/encryption.rake` if encrypting an existing column

### Step 3: Service object
- `app/services/<domain>/<action>_service.rb`, inherits `ApplicationService`
- `step(result)` to chain, `try_external(ErrorClass) { }` for outside calls, `Success(data)` / `Failure(code:, message:)`
- One service = one action; named keyword arguments; no `params`, `session` or current user inside
- Heavy pure computation: write it in Ruby first; move to Rust only after a benchmark (`/rust`)

### Step 4: Background job (if needed)
- `app/jobs/<domain>/<name>_job.rb`, inherits `ApplicationJob`, `queue_as` a queue listed in `config/sidekiq.yml`
- Primitive arguments only; find records inside `perform`; cron entries in `config/sidekiq_cron.yml`

### Step 5: Controller
- Authenticated screens inherit `App::BaseController` (native-only + session + Pundit); public pages inherit `ApplicationController` with `allow_unauthenticated_access` and `layout "public"`; JSON for native screens inherits `Api::V1::BaseController`
- Pattern match the Result; respond with `format.html` and `format.turbo_stream`; `:unprocessable_content` on failed forms, `:see_other` after non-GET redirects

### Step 6: Routes
- Inside `scope "(:locale)"`; authenticated resources inside `namespace :app`
- Health, native shell endpoints, API and webhooks stay outside the locale scope

### Step 7: Views
- Every string through `t()`; BEM classes; tokens only; `.stack`, `.cluster`, `.grid`, `.container`
- Reuse `.card`, `.btn`, `.badge`, `.input`, `.input-group`, `.tab-bar`, `dialog.dialog`
- `turbo_frame_tag` for independently updating sections; native `<dialog>` for modals
- Mobile first

### Step 8: CSS (if a new component is needed)
- `app/assets/stylesheets/components/<name>.css` or `pages/<name>.css`, linked from the layout that uses it
- Tokens only (`var(--color-*)`, `var(--space-*)`, `var(--text-*)`, `var(--radius-*)`, `var(--transition-*)`, `var(--shadow-*)`)
- `@starting-style` for enter animations; animate `transform` and `opacity` only; `:focus-visible` ring; `forced-colors` fallback; `prefers-reduced-motion`
- 48 px touch targets; `min-width` media queries only

### Step 9: Stimulus controller (if interactivity is needed)
- `app/javascript/controllers/<name>_controller.js`; targets, values, classes; clean up everything in `disconnect()`
- Stimulus never owns server state; Turbo does. Fetch only for ceremonies and bridge replies (see `passkey_controller.js`)

### Step 10: i18n
- English keys in `config/locales/en/...`, Spanish keys in `config/locales/es/...`, same change
- `%{variable}` interpolation; `one:`/`other:` pluralization; no em dashes

### Step 11: Tests
- Model spec, service spec (success, failure, step halting, try_external), request spec that renders the page (`native_headers`, `sign_in_as`), job spec with `have_enqueued_job`
- `mise exec -- bundle exec rspec <file>`

### Step 12: Verify
- `mise exec -- bundle exec rspec` (the i18n specs catch missing keys, parity and hardcoded text)
- `mise exec -- bin/rubocop`, `mise exec -- bin/brakeman --no-pager`
- Dark and light, phone and desktop, inside and outside the native shells (`/verify`)

## Critical rules (never violate):
- Pure CSS only; Hotwire only; service objects with Result for all business logic
- English-first i18n with Spanish parity; no em dashes; every string through `t()`
- Passkeys only; the web is informational, sessions live in the native shells
- Ruby only through `mise exec --`; never read credentials files; the operator runs git
- Rust only inside `vendor/gems/aluni_core`, called only from `app/services/core/`
- Never use hacks or workarounds; check existing conventions first
