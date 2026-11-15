# Onboarding: the profile-building chat

Aluni's first product screen is a chat that builds a farm profile. Gemini drafts
every line Aluni says; the app decides what is saved, when the conversation moves
on, and what happens when Gemini cannot answer. This document covers the engine
(`app/services/onboarding/`). The chat UI, the routes and the demo runbook are
described in their own sections below (Stream F adds them).

Read with: `docs/DATA_MODEL.md` (the five tables), `docs/INTEGRATIONS.md`
(Gemini client), `docs/RAILS_PATTERNS.md` (services), `docs/I18N.md`.

## Flow

```
/app/onboarding
  welcome -> location -> land -> crops -> soil -> operation -> goals -> summary -> completed
  every turn: farmer bubble + Aluni bubble (+ confirm card with the staged facts)
  nothing is written to profile, farm, field or crops until the farmer taps "Save selected"
```

One turn, in order (`Onboarding::ReplyService`):

1. `EnsureProfileService` gives the user a profile, one farm with one field and
   an `OnboardingSession` row (idempotent). `Failure(code: :blocked)` while the
   row is blocked, `Failure(code: :empty)` for a blank message. These are the
   only two Failures a controller sees; everything else is a `Success`.
2. The text is redacted (`Onboarding::Redactor`) and appended to the encrypted
   transcript as `{ "role" => "user", "text" => ..., "at" => iso8601 }`.
3. On the request thread: `ProfileSnapshot`, the system prompt
   (`Onboarding::SystemPrompt.build`), and the Gemini `contents` (the last
   `context_turns` as alternating `user` / `model` parts). All database reads
   happen here; nothing in a thread touches the database.
4. Two Gemini calls run side by side: `ClassifyIntentService` in a `Thread`
   (`Rails.application.executor.wrap`, its own `Gemini::Client`, every error
   rescued to "safe") and `DraftReplyService` on the request thread. The join is
   wrapped in `ActiveSupport::Dependencies.interlock.permit_concurrent_loads`
   and bounded by `gemini_timeout`; a classifier that has not finished counts
   as safe.
5. Unsafe: a strike, the draft is thrown away, Aluni answers with
   `onboarding.refusals.<abuse_type>` (`refusal: true`). At `strike_limit`
   strikes the row is blocked for `block_ttl` and the answer is
   `onboarding.blocked`.
6. Draft failed (Gemini down, bad JSON, or the `gemini` switch paused): Aluni
   answers with a continuation line (`onboarding.continuations.<topic>`, rotated
   by `fallbacks_count`), the message is kept in `pending_message` and replayed
   into the next request so the model still addresses it (`degraded: true`).
   The farmer's turn stays in the transcript.
7. Otherwise the answer's `updates` go through the allowlist, the pin is merged
   (see below), the result replaces `session.proposal`, and when
   `topic_complete` is true the topic advances (the next topic's
   `onboarding.transitions.<topic>` line is appended to Aluni's bubble) or, on
   the last topic, `CompleteService` closes the session and stores the segment.

The transcript is trimmed to `max_turns`; `turns_count`, `last_message_at` and
`language` are updated on every answered turn. An unexpected exception anywhere
is logged and becomes a continuation line; the service never raises.

## Public API

| Service | Call | Returns |
|---|---|---|
| `Onboarding::ReplyService` | `call(user:, text:, locale:, coords: nil)` | `Success(payload)`; `Failure(code: :blocked, blocked_until:)`, `Failure(code: :empty)` |
| `Onboarding::ApplyProposalService` | `call(user:, accepted: [keys])` | `Success(applied: { "profile.budget_level" => "low", ... })`; `Failure(code: :expired)`, `Failure(code: :invalid, messages:)` |
| `Onboarding::DiscardProposalService` | `call(user:)` | `Success(session)` |
| `Onboarding::SkipTopicService` | `call(user:, locale: nil)` | `Success(topic:, transition:, completed:)` |
| `Onboarding::CompleteService` | `call(user:)` | `Success(segment:)` |
| `Onboarding::ResetService` | `call(user:)` | `Success(session)` |
| `Onboarding::SegmentClassifier` | `call(user:)` | `Success(segment:)` |
| `Onboarding::ClassifyIntentService` | `call(text:, client: nil)` | always `Success(safe:, language:, abuse_type:)` |
| `Onboarding::DraftReplyService` | `call(messages:, system_instruction:, client: nil)` | `Success(parsed_hash)`; `Failure(code: :external_error)`, `Failure(code: :paused)` |

`ReplyService` payload (symbol keys):

```ruby
{ user_text: "I farm 12 hectares",            # the redacted text, what the UI echoes
  assistant_text: "Twelve hectares. Rainfed?", # Aluni's bubble
  transition: nil,                             # or the next topic's line when the topic advanced
  topic: "land",                               # the topic after this turn
  topic_complete: false,
  proposal: { "field" => { "area" => 12.0, "area_unit" => "hectares" } },  # nil when nothing is staged
  progress: { index: 3, total: 8 },            # 1-based position of the current topic
  completed: false, degraded: false, refusal: false }
```

`coords` is `{ latitude:, longitude:, source: }` from the browser's share-location button
(`source: "geolocation"`) or a point placed on the field map (`source: "map"`); strings or
numbers, out-of-range values are ignored, and an unknown source counts as `geolocation`.

## Topics and how to add one

`config/onboarding/topics.yml` holds the plan: global `rules` and an ordered list
of topics with `key`, `required` and `guidance`. It is English model guidance,
not copy, so it lives outside the locales. `Onboarding::Topics` reads it
(`keys`, `first`, `size`, `index`, `next`, `guidance`, `required`, `rules`,
`title_key`) and `validate!` runs at boot from
`config/initializers/onboarding.rb`: a duplicate key, a topic without guidance
or a `required` fact the snapshot cannot read (`profile.x`, `farm.x`,
`field.x`, `field.soil.x`, `crops`) stops the app from starting.

`required` is shown to the model as `REQUIRED FACTS` and read by
`ProfileSnapshot#required_known?`; it does not hard-gate the advance, because a
fact sits in the confirm card before it is saved and "I do not know" is a valid
end to the soil topic.

To add a topic:

1. Insert it in `topics.yml` at its position, with 3 to 8 lines of guidance that
   end with the condition for `topic_complete`.
2. Add `onboarding.topics.<key>` (short title), `onboarding.transitions.<key>`
   and a list of two or three `onboarding.continuations.<key>` in
   `config/locales/en/en.onboarding.yml` and `es/es.onboarding.yml`.
3. If it gathers new facts, extend the model constants first (the schema and the
   allowlist follow them), then `onboarding.field_labels.*` and
   `onboarding.values.*` for the confirm card.
4. `topics_spec.rb` asserts the order; update it.

## The system prompt

`Onboarding::SystemPrompt.build(snapshot:, topic:, locale:, display_name:, opening: nil)`
stacks, in this order: the persona (Aluni, first person, two short sentences and
one question, never "AI", "model" or "bot"), `Gemini::LanguagePrompt.lock(locale)`,
`CURRENT TOPIC` with `REQUIRED FACTS`, `TOPIC GUIDANCE`, `PROFILE SO FAR`
(`ProfileSnapshot#to_prompt`), `RULES` (from the yml) and `OUTPUT RULES`. On the
first turn the welcome bubble the page already showed is appended as
`OPENING LINE ALREADY SHOWN` so Aluni does not greet twice.
`spec/fixtures/onboarding/system_prompt.txt` is the golden master; regenerate it
from `SystemPrompt.build` when the skeleton changes on purpose.

## The response schema and the allowlist

`Onboarding::Allowlist` reads every vocabulary straight from the models
(`FarmerProfile.roles.keys - ["unknown"]`, `FarmerProfile::GOALS`,
`Field::SOIL`, `FieldCrop.roles.keys`, ...). `DraftReplyService::RESPONSE_SCHEMA`
is built from those lists, and `Allowlist.filter` uses the same lists to drop
anything the model should not have said, so the two cannot drift. The schema
stays inside Gemini's subset (`type`, `properties`, `required`, `enum`, `items`,
`nullable`):

```
response_text (string, required)   topic_complete (boolean, required)
location_guess (object, nullable): latitude, longitude, label, confidence low|medium|high
updates:
  profile: role experience team team_size units land_tenure budget_level risk_tolerance
           goals[] equipment[] livestock[] market_channels[] practices[] notes
  farm:    name country_code admin_area
  field:   name area area_unit irrigation water_source cropping_intensity
           soil_texture soil_depth soil_drainage soil_ph soil_salinity soil_fertility soil_lab_test soil_problems[]
  crops[]: crop_name scientific_name season_year planting_month harvest_month role
```

Filtering rules: unknown sections and keys are dropped; an enum value outside the
list is dropped; list values are intersected with the list; `soil_*` keys fold
into `field["soil"]`; `ph` must be 0..14, months 1..12, `season_year` within
`FieldCrop::YEARS`, `area` positive, text capped at 100 chars (notes 2000);
a crop row needs `crop_name` and `season_year`, defaults `role` to `main`, and
the last row wins for a `[season_year, role]` pair. Latitude and longitude from
`updates` are ignored: the pin only comes from `coords` (confirmed,
`geolocation` or `map`) or from a `location_guess` with confidence `medium` or `high`
(approximate, `assistant`, with `place_label`). The browser pin wins over a guess.

## The proposal and the accepted keys (contract with the UI)

`session.proposal` is a string-keyed hash, replaced on every answered turn:

```ruby
{ "profile" => { "budget_level" => "low", "goals" => ["rotation"] },
  "farm"    => { "name" => "Finca Ana" },
  "field"   => { "area" => 12.5, "area_unit" => "hectares", "latitude" => 9.93, "longitude" => -84.08,
                 "place_label" => "Cartago", "location_confidence" => "approximate", "location_source" => "assistant",
                 "soil" => { "texture" => "medium", "ph" => 6.1 } },
  "crops"   => [ { "season_year" => 2025, "role" => "main", "crop_name" => "Corn", "scientific_name" => "Zea mays",
                   "planting_month" => 4, "harvest_month" => 10 } ] }
```

The confirm card posts accepted keys: `profile.<key>`, `farm.<key>`,
`field.<key>`, `field.soil.<key>`, `crops.<season_year>.<role>`. The pin is one
fact: accepting any of `field.latitude`, `field.longitude`, `field.place_label`,
`field.location_confidence` or `field.location_source` applies all five
(`Allowlist.keys_for(proposal)` lists the keys a card should offer, with the pin
once as `field.latitude`). `ApplyProposalService` reads the proposal from the row
(never from the request), keeps the accepted keys, filters again, and writes
profile, farm, main field (soil merged into the existing hash) and crops
(upserted by `[field_id, season_year, role]`, `source: "assistant"`) in one
transaction, then clears the proposal. An empty proposal is `Failure(:expired)`;
a validation error rolls everything back into `Failure(:invalid, messages:)`.
Accepting nothing clears the proposal and applies nothing.

## The session row

`onboarding_sessions`: `topic`, `status` (active / completed), `completed_at`,
`transcript` (JSON array of `{ role, text, at }`, encrypted, last `max_turns`),
`proposal` (jsonb, staged facts), `pending_message` (encrypted, the message
Aluni could not answer), `fallbacks_count`, `turns_count`, `strikes`,
`blocked_until`, `language`, `last_message_at`. Postgres is the only store: a
refresh or a day away resumes from the row, specs need no Redis, and Active
Record encryption covers "encrypted at rest". `ResetService` empties the chat
and the counters but keeps profile data and an active block (a reset is not a
way out of one). `CompleteService` keeps the transcript for a later chat.

## Abuse rules

- `Onboarding::Redactor` runs before storage: emails become `[email]`, groups of
  7+ digits with spaces, dashes, dots or parentheses become `[phone]`, tags are
  stripped, the text is capped at 2000 chars. Decimals (`42.0123`, `-93.75`,
  `9.934567`) are never touched so typed coordinates survive. The redacted text
  is what is stored, echoed and sent to Gemini.
- `ClassifyIntentService` (Flash, 128 tokens) answers `safe`, `language`,
  `abuse_type` in `none insult sexual spam injection off_topic_hostile`. The
  prompt says: when in doubt, mark safe. It fails open on any error.
- Strikes live on the row: `strike_limit` (3) unsafe messages block the chat for
  `block_ttl` (24 h); `ReplyService` then returns `Failure(:blocked)` and the
  controller answers 429. Per-IP throttles are Rack::Attack's job.
- Copy for refusals and the block lives in `onboarding.refusals.*` and
  `onboarding.blocked`, in character, both locales.

## Fallbacks

Every Gemini problem is a `Success` in character so the bubble always arrives:
`DraftReplyService` turns `nil` and bad JSON into `Failure(:external_error)` and
a paused switch into `Failure(:paused)` (never left to `ApplicationController`,
which would answer the fetch with a redirect); `ReplyService` turns both into a
continuation line and keeps the message pending. `onboarding.error_fallback` is
the last resort when a topic has no continuation list.

Limits live in `config/initializers/onboarding.rb`
(`Rails.configuration.x.onboarding`): `max_turns` 40, `context_turns` 20,
`strike_limit` 3, `block_ttl` 24 h, `gemini_timeout` 20 s, `max_output_tokens`
1024, `classifier_max_tokens` 128. `Gemini::Client.new(timeout:)` applies the
timeout per call; `chat(response_schema:, max_tokens:)` gives structured output
in multi-turn mode with the same unicode repair as `generate`.

## The two-thread turn

Only `Service.call` runs inside the thread (it has its own `catch(:halt)`),
wrapped in `Rails.application.executor.wrap`, with a separate `Gemini::Client`,
and the request thread waits with `interlock.permit_concurrent_loads { join(timeout) }`
so an autoload in development cannot deadlock. The constants the thread needs
are referenced before it starts. Puma runs 3 threads in production; one chat
turn briefly uses two. If that ever matters, the classifier can run after the
draft instead of beside it with no change to the payload.

## Segments

`Onboarding::SegmentClassifier` is pure Ruby over the snapshot (areas summed in
hectares, acres divided by 2.47105): under 2 ha with a solo or family team, low
budget and nothing sold beyond `own_use` / `local_market` is
`smallholder_subsistence`; over 200 ha, or a crew selling `wholesale`,
`contract` or `export`, is `large_commercial`; 20 to 200 ha, or a tractor plus
a planter or harvester with a `small_team` or `crew`, is `mid_mechanized`;
under 20 ha with any channel beyond `own_use` is `small_commercial`; otherwise
`unknown`. Thresholds are defaults to tune.

## Specs

Four stubbing levels under `spec/services/onboarding/`: the client doubled
(`draft_reply_service_spec`, `classify_intent_service_spec`); WebMock at the
HTTP level (`reply_integration_spec`, tagged `:gemini_api`, the classifier and
the draft told apart by their schemas because they run in parallel); the
sub-services stubbed (`reply_service_spec`); and plain database specs
(`apply_proposal_service_spec`, `skip_topic_service_spec`,
`complete_service_spec`, `reset_service_spec`, `segment_classifier_spec`,
`topics_spec`, `redactor_spec`, `system_prompt_spec` with the golden master).

Run: `mise exec -- bundle exec rspec spec/services/onboarding spec/services/gemini spec/i18n`.

## The screens

**Landing** (`app/views/pages/home.html.erb`, browsers only). `pages/home/_mascot` mounts Aluni (`mascot_controller.js`, `docs/DESIGN_SYSTEM.md`): the stage walks in from the bottom-left corner, waves, and shows the greeting bubble with "Let's go" (only while sign-ups are open) and "Show me around" (a plain hash jump to the tour, `data-turbo="false"` like every in-page anchor on the landing, because Turbo would otherwise re-render the page and restart the walk-in). "Let's go" dispatches `mascot:lets-go`; `pages/home/_chat_panel` (`landing_chat_controller.js` together with `passkey_controller.js` in create mode) opens as a bottom sheet on phones or a 420 px side panel from 1025 px, dispatches `mascot:dock { selector: "#landing-chat-companion" }`, and runs three scripted steps with no Gemini and no account: the name (never posted, it fills the hidden `display_name`), the language (two buttons; the remaining lines switch locale client-side from `ApplicationHelper#landing_chat_script`), and the passkey (hidden `display_name` + `locale` inputs posted to `/sign_up/options`; `RegistrationsController#create` sets the locale cookie and answers `redirect_to: /app/onboarding`). Progress survives a reload through `sessionStorage` (`aluni.landing-chat`). A signed-in visitor sees a "welcome back" line and a link to the app instead.

**`/app/onboarding`** (`App::OnboardingController`, `app/views/app/onboarding/`). One page, every turn a Turbo Stream. Layout `.onboarding`: the chat (`.chat`: `__log` with the bubbles, `__composer`, the progress dots, the confirm card slot, the location tools while the topic is `location`) and, from 1025 px, a sticky companion column (`<aside id="chat-companion" data-mascot-dock>`) with `shared/mascot_companion` (the mascot in docked mode, idle, talking on every new assistant bubble) above the profile preview (`<details open>`; below 1025 px the preview folds under the chat). Stream targets, enforced by `spec/views/onboarding_turbo_stream_targets_spec.rb`: `#onboarding-messages` (append), `#onboarding-confirm` (update), `#onboarding-progress` (replace), `#onboarding-location-tools` (update), `#onboarding-notice` (update), `#profile-preview` (replace). Actions: `message` (POST text, optional latitude/longitude from the share-location button), `confirm` (accepted keys, "Save selected"), `discard` ("Not now"), `skip`, `complete` (303 to `/app`), `reset` (DELETE). The first bubble before any Gemini call is `onboarding.welcome_message`. `App::HomeController` forwards to the chat while `User#onboarding_complete?` is false and shows a recap plus "Talk to Aluni" afterwards.

**Stimulus** (`app/javascript/controllers/`): `chat` (intercepts the composer and the quick-answer forms, posts with `Accept: text/vnd.turbo-stream.html`, renders the stream whatever the status so a 429 notice shows, Enter sends, Shift+Enter breaks a line, `AbortController` on disconnect), `chat-message` (scrolls a new bubble into view and dispatches `mascot:speak { chars }` for assistant bubbles; history bubbles are `silent`), `geolocate` (`getCurrentPosition` fills the hidden pin, `location_source` and a fixed composer text, then `geolocate:located` submits; `fill` does the same for a map point), `field-map` (the location step's Leaflet map, loaded lazily from `vendor/javascript/leaflet.js`: EOxCloudless Sentinel-2 imagery or OpenStreetMap tiles, a draggable pin, Move pin to centre for keyboards, Use this point dispatches `field-map:picked` to `geolocate#fill`; opens on its own when a pin exists, the GIBS picture is the no-JavaScript fallback), `landing-chat` (above), `mascot` (`docs/DESIGN_SYSTEM.md`). Window events: `mascot:ready|arrived|docked|fallback|lets-go` from the mascot; `mascot:speak|dock|hide|show` to it.

**Throttle**: `RACK_ATTACK_ASSISTANT_PATH` in `config/initializers/rack_attack.rb` limits `/app/onboarding/*` writes to 20 per minute and 150 per hour per IP.

## Demo runbook

1. A configured Gemini backend (development: `gemini.api_key` in the credentials; production: `GEMINI_BACKEND=vertex` with `GOOGLE_CLOUD_PROJECT`, `docs/INTEGRATIONS.md`) and `mise exec -- bin/rails 'platform:resume[gemini]'`; while Gemini is paused or unconfigured Aluni answers only with the continuation lines (`degraded: true`).
2. `mise exec -- bin/dev`, open `http://localhost:3000` (a secure context: passkeys and the share-location button need one; a phone needs an https tunnel with `APP_DOMAIN`, `docs/AUTH.md`).
3. Wait for Aluni to walk in, press "Let's go", give a name, pick a language, create the passkey. The chat opens at the welcome topic.
4. Walk the eight topics in English and in Spanish; tick a few proposals, skip one topic, refresh once mid-way (the transcript resumes from the row), send an insult to see the refusal, pause Gemini (`platform:pause[gemini]`) to see the calm continuation line, finish to reach the recap on `/app`.
5. `DELETE /app/onboarding` ("Start over" on the page) resets the chat and keeps the profile data.

## Phase 2 candidates

A map for field boundaries (`fields.boundary`); the first data fetches (NASA POWER climatology, SSURGO and CDL for US pins, GAEZ suitability) behind switchboard-guarded clients; crop cards built from ECOCROP, FAO-56 and GAEZ ("the optimal environment for potatoes"); the real `/app` home; a welcome notification through `NotificationRouter`.
