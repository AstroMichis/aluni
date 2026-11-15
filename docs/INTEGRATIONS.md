# Integrations

Every outside service has one client class, a switchboard guard, structured errors, explicit timeouts, and WebMock stubs in its specs. Nothing is called until the operator resumes it (`platform:bootstrap` pauses `cron gemini mail push` on the first deploy).

## Gemini (`app/services/gemini/client.rb`)

- Two backends, same request and response bodies (`Gemini::Client.backend`, ENV `GEMINI_BACKEND`): `api_key` (default; `BASE_URL = https://generativelanguage.googleapis.com/v1beta`, key from credentials `gemini.api_key` as `x-goog-api-key`) or `vertex` (Vertex AI on the GCP VM: no key on disk, `Gemini::VertexToken` fetches an OAuth token for the VM's attached service account from the GCE metadata server and caches it per process (outside production, `GOOGLE_OAUTH_ACCESS_TOKEN`, e.g. from `gcloud auth print-access-token`, replaces the metadata server so a laptop can use Vertex with no key); host from `GOOGLE_CLOUD_PROJECT` and `GOOGLE_CLOUD_LOCATION`, `global` by default). `Gemini::Client.configured?` (behind `Platform::Features.gemini?`) means a key for `api_key` or a project for `vertex`. Production deploys with `GEMINI_BACKEND=vertex` (`.github/workflows/deploy.yml`). A token failure surfaces as `last_error[:type] == :api_error`, so callers see the same `nil` as any other failure.
- Model tiers from `config.x.gemini` (`GEMINI_FLASH_MODEL`, `GEMINI_PRO_MODEL`, `GEMINI_TRANSCRIBE_MODEL`, default `gemini-3.8-flash`) and `GEMINI_CHAT_MAX_OUTPUT_TOKENS` (2048). `thinking_config_for` keeps thinking minimal per model family.
- `generate(prompt, system_instruction:, images:, response_schema:, max_tokens:)` single turn, temperature 0.3, inline base64 images, structured JSON via `responseMimeType` + `responseSchema`; `chat(messages:, system_instruction:, response_schema:, max_tokens:)` multi turn, temperature 0.4, the same structured JSON when a schema is given. `Gemini::Client.new(model:, timeout:)` overrides the 30 s read timeout per caller (the chat uses 20 s).
- Retries: backoffs `[0.5, 1.5, 3.0]` s plus jitter within a 6 s budget, `Retry-After` parsed from the 429 message (capped at 5 s); retryable types `rate_limited`, `service_unavailable`, `network_error`, `empty_response`. On exhaustion returns `nil` and exposes `last_error` (`{ type:, status:, message:, retry_after: }`). Faraday: JSON in and out, `retry max: 2`, timeout 30 s, open timeout 10 s.
- `Platform::Switchboard.guard!(:gemini)` right before the request; `fix_unicode_escapes` repairs a known structured-output bug.
- Callers handle `nil`, rescue `JSON::ParserError`, and never show a raw processing error to a person: `try_external(Faraday::Error, JSON::ParserError)` in services.
- `Gemini::LanguagePrompt.lock(locale)` forces the answer language.
- The onboarding chat (`docs/ONBOARDING.md`, `app/services/onboarding/`) is the first assistant: the encrypted transcript lives on `onboarding_sessions` (Postgres, so a refresh resumes), `Onboarding::Redactor` scrubs emails and phone numbers before storage, `Onboarding::ClassifyIntentService` runs beside every reply with a 3-strike 24 h block, and Rack::Attack throttles `/app/onboarding/*` at 20/min and 150/hour per IP (`RACK_ATTACK_ASSISTANT_PATH`).
- Pictures of the farmer's area come from NASA GIBS WMS (`Onboarding::AreaImage.url`), loaded by the browser as an `<img>` (`img-src https:` in the CSP); the server never fetches them, so there is no client and no switchboard entry. The default layer is static Blue Marble; the daily true-colour layer needs a `TIME`.
- Specs: `spec/services/gemini/client_spec.rb` (WebMock); `spec/support/external_apis.rb` fails the suite if any other spec reaches a Google host.

## Geocoding (`app/services/geocoding/client.rb`)

OpenStreetMap's Nominatim, through the server only (the browser never calls it): `search(query, locale:)` for the field finder's town or address box and `reverse(latitude:, longitude:, locale:)` for the confirmed pin, both returning normalised rows `{ label:, latitude:, longitude:, country_code:, admin_area: }` or `nil` with `last_error`. Rules of the service, which allows about one request per second in total and no autocomplete: search only on submit, an identifying `User-Agent` (`Aluni/1.0 (+https://aluni.us)`), `Rails.cache` for a day (search by locale and normalised query, reverse by coordinates rounded to three decimals), no retry on a 429, and the `places/ip` throttle (20 per minute) in Rack::Attack. `Platform::Switchboard.guard!(:geocoding)` runs before each request and `Platform::ServicePaused` is rescued inside the client (a Turbo Frame cannot follow a redirect), so `PlacesController` renders a calm line in the frame either way. The provider sits behind this one class: Photon or a paid geocoder can replace it without touching the finder. Map tiles are plain images (`img-src https:`): OpenStreetMap's standard tiles and Esri World Imagery for the satellite toggle, both attributed in the map; check Esri's terms before real traffic.

## Meteomatics (`app/services/meteomatics/client.rb`)

- Weather API, current conditions and forecast at 1 km (`docs/data_sources/meteomatics.md`). The hackathon offer gives 1,000 queries a day.
- Off until configured: credentials `meteomatics.{username,password}` or ENV `METEOMATICS_USERNAME` / `METEOMATICS_PASSWORD` into `config.x.meteomatics` (`config/initializers/meteomatics.rb`). `Platform::Features.meteomatics?` is false while either is missing, and the client returns `nil` with `last_error[:type] == :not_configured` without calling out.
- `forecast(lat:, lon:, hours: 72, step: "PT1H", parameters: FORECAST_PARAMETERS)` returns `{ "t_2m:C" => [[Time, value], ...] }`, at most 10 parameters per query. HTTP Basic auth, timeout 20 s, retries on 502/503/504.
- Successful answers are cached in `Rails.cache` per point rounded to 0.01° and per hour (`METEOMATICS_CACHE_TTL_SECONDS`, default 3600). Failures are not cached.
- `Platform::Switchboard.guard!(:meteomatics)` before each request. `platform:bootstrap` pauses it on a new server.
- Errors: `last_error` `{ type:, status:, message: }`, with types `unauthorized`, `rate_limited`, `service_unavailable`, `api_error`, `network_error`, `empty_response`, `invalid_request` and `not_configured`.
- Specs: `spec/services/meteomatics/client_spec.rb` (WebMock).

## Planetary Computer (`app/services/planetary_computer/client.rb`)

- Sentinel-2 L2A from Microsoft Planetary Computer, with no account or key (`docs/data_sources/sentinel2_stac.md`).
- `scenes(lat:, lon:, from:, to:, max_cloud: 30)` runs a STAC search over the point, least cloudy first. `point_value(lat:, lon:, item:, expression:)` calls the data API's (TiTiler) `item/point`, which computes band math server side, so no imagery is downloaded.
- `ndvi(lat:, lon:, from:, to:)` returns `[{ date:, ndvi:, scene:, cloud_cover: }, ...]` newest first. It keeps only scenes whose pixel is clear in the scene classification (`SCL` 4, 5 or 6), costs two point calls per scene (at most 8 scenes), and is cached for 6 h.
- Free, so it ships unpaused, but it has a switch: `Platform::Switchboard.guard!(:planetary_computer)`. Timeout 20 s, retries on 429/502/503/504.
- Specs: `spec/services/planetary_computer/client_spec.rb` (WebMock).

## Outbound client pattern

One class per provider under `app/services/<provider>/client.rb`: Faraday with JSON middleware and `faraday-retry`, explicit timeouts, structured error classes, `Platform::Switchboard.guard!(:service)` before each call (or `Platform::FaradayPauseGuard` as middleware for clients with several connections), a `PlatformSwitch::SERVICES` entry and a `Platform::Features` flag when the integration ships off by default.

## Public data sources

`DataSources::Client` is the base of the no-account data clients (`NasaPower::Client`, `Gaez::Client`, `Ssurgo::Client`, `Usgs::ElevationClient`, `Cdl::Client`, `Fcc::Client`): Faraday with retries and timeouts, one error class, and `Platform::Switchboard.guard!(:data)` before each request (`PlatformSwitch::SERVICES` includes `data`, on by default). Only `Fields::FetchObservationsJob` calls them; see `docs/FIELDS.md`.

## Inbound webhooks (shape, not built)

`namespace :webhooks` is outside the locale scope. Each provider gets an `ActionController::API` controller (no session, no CSRF) that caps the body from `Content-Length` (413), verifies the provider's signature with `ActiveSupport::SecurityUtils.secure_compare`, records the delivery in a `webhook_events` table with a unique `(source, dedupe_key)` so redeliveries are no-ops that still answer 200, and enqueues a job that re-fetches the object from the provider before acting. A webhook controller never mutates business state in the request. Wrap the route in `constraints: ->(_r) { Platform::Features.<provider>? }` so it 404s until the integration is turned on. Rack::Attack throttles `/webhooks` at 100/min per IP.

## Off until configured

An integration that costs money ships with no defaults: its initializer reads ENV or credentials into `config.x.<area>`, `Platform::Features.<area>?` answers false while unset, and every caller checks the flag or gets a skipped outcome (see the push channel). The SMS pattern from the reference is the template if SMS ever arrives.

## Push (`action_push_native`)

`config/push.yml` reads APNs (`action_push_native.apns.{key_id,encryption_key,team_id,topic}`) and FCM (`action_push_native.fcm.{encryption_key,project_id}`) from credentials; `APNS_DEVELOPMENT` picks the sandbox (default on outside production). `DeviceToken` rows (ios/android, registered by the shells through `App::DeviceTokensController`) are mirrored into `action_push_native_devices` by `Notifications::PushDevices` before a push. `ApplicationPushNotificationJob` runs on the `push` queue so pausing `push` holds it. Unconfigured: the channel is skipped and the next one takes over.

## Web Push (`web-push`)

VAPID keys in credentials `web_push.{public_key,private_key,subject}` (`bin/rails web_push:vapid_keys` prints a pair). `WebPushSubscription` rows per account and browser endpoint (`App::WebPushSubscriptionsController`, `web_push_controller.js`, `web_push/_opt_in.html.erb`); `Notifications::WebPushJob` sends and deletes expired subscriptions; the service worker shows the notification and opens its URL.

## Notification router

`NotificationRouter.deliver(recipient:, purpose:, payload:, idempotency_key:)` reads `config/notification_purposes.yml` (validated at boot by `Notifications::Purposes`), tries the purpose's channels in order (`push`, `web_push`, `email`) and records every attempt on a `NotificationDelivery`. Same key twice: once sent, nothing is sent again. The shell ships with no purposes and one generic mailer action (`NotificationMailer#generic(user, subject, body)`).

## Mail

`ApplicationMailer` sends from credentials `mailer.from` (or `MAILER_FROM`). Development writes mail to `tmp/mails`; production uses SMTP from credentials `smtp.*` (pick a free tier such as Resend or Brevo; add SPF, DKIM and DMARC at the DNS provider). `Platform::MailPauseInterceptor` drops mail while `mail` is paused unless the message carries `X-Platform-Critical`.

## Storage (Cloudflare R2)

`config/storage.yml` `cloudflare_r2` uses the S3 adapter (`endpoint https://<account_id>.r2.cloudflarestorage.com`, `region auto`, `force_path_style`, checksum settings `when_required`), credentials `r2.*` with `R2_*` ENV fallbacks, bucket `R2_BUCKET` (default `aluni`). Production proxies files through the app (`resolve_model_to_route = :rails_storage_proxy`), so the bucket stays private; variants use libvips (`Vips.block_untrusted(true)`). R2 CORS must be configured in the Cloudflare dashboard for direct uploads.
