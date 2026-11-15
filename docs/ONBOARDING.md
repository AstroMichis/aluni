# Getting a farmer started

Setup is not a conversation. Aluni, the mascot, is the preloader and the host; the
only required step is the field pin; crop and irrigation are two taps; everything
else is progressive and lives in the app. The Gemini chat (`/app/onboarding`,
"Ask Aluni") is optional and saves what it hears right away with an Undo.

Read with: `docs/DESIGN_SYSTEM.md` (preferences, the mascot, `.panel`, `.intro`),
`docs/DATA_MODEL.md` (the tables), `docs/INTEGRATIONS.md` (Gemini and geocoding
clients), `docs/AUTH.md` (the sign-up that carries the field), `docs/I18N.md`.

## The flow

```
GET /   (locale from the cookie, else Accept-Language)
  Aluni sprouts in the centre while the hero loads (the SVG twin at once, the 3D character when ready),
  moves to its corner once the hero has revealed (0.9 s minimum, 2.5 s fallback), waves, and speaks:
  first visit   "Hi, I'm Aluni. I'll keep things in English. ¿Prefieres español?"  [English] [Español]
                "Make it comfortable" [Larger text] [Read aloud] [Less motion] [High contrast]   [Looks good]
  afterwards    "Let's find your field."  [Find my field] [Show me around]
Field finder (panel: bottom sheet on phones, side panel from 1025 px; Aluni docks into its header)
  1 Locate   the device position is asked for as the step opens (allow the prompt and the pin lands)
             or  town / address -> Search (Turbo Frame #place-results)
             Leaflet map (OpenStreetMap tiles, satellite toggle, [Use my location] to ask again), draggable pin  ->  [This is my field]
             -> reverse geocoding (Turbo Frame #place-summary): place, region, country, coordinates
  2 Basics   crop now (type-ahead over config/crops/common.yml, free text normalised later)
             [Rainfed] [Irrigated]   area (optional) [ha | acres]   [Continue] [Skip for now]
  3 Save     signed out: your name + [Create passkey]  (flat hidden inputs carry pin and basics)
             signed in:  [Save field]  (PATCH /app/fields/:id)
  -> /app
/app/onboarding   optional "Ask Aluni": welcome -> crops -> soil -> goals -> summary; auto-apply + Undo toast
```

## Language and comfort first (`Preferences`, `PreferencesController`, `pages/home/_intro`)

The page renders in the locale the browser asked for (`Accept-Language`, then the
`locale` cookie), so the first bubble is already in the right language and only
offers the other one. The bubble is `pages/home/_intro` inside the mascot's
speech bubble: two language chips (each a submit button posting
`preferred_locale` to `POST /preferences`; the server sets the locale cookie and
redirects to the same page in that language, where the same bubble appears again),
four pill toggles (`intro#toggle` → `preferences.set(name, value)`: larger text,
read aloud, less motion, high contrast; each applies at once on `<html>` and is
persisted through the hidden `shared/_preferences_form`), and "Looks good", which
posts `done=1` (marks `seen_welcome`) and swaps in `pages/home/_start_bubble`.
Returning visitors get the start bubble directly. The choices live in the
`aluni_prefs` cookie and, once signed in, in `users.preferences`; the layouts
render them on `<html>` and the `preferences` controller re-applies them after
every Turbo visit. Read aloud uses the browser's own voices (`speech_controller.js`):
any new Aluni line dispatches `speech:read { text, lang }` and is spoken only when
the preference is on. The small `shared/_access_buttons` in the nav (theme, text
size, read aloud) stay available afterwards, from 641 px.

## The field finder (`pages/home/_finder`, `finder_controller.js`, `field_map_controller.js`)

Opens on the window event `mascot:lets-go` (the bubble's "Find my field", the hero
button and the tour's last step fire it through `emit_controller.js`) and docks the
mascot into `#finder-companion`. It is a `.panel` with three steps, one visible at a
time, each announced (`aria-live`) and spoken (`data-speak`).

1. **Locate.** The step asks the device for its position the moment it opens without
   a pin (the finder dispatches `finder:locate`, `geolocate_controller.js#request`):
   the person has just said "Find my field", so the browser's permission prompt is
   the only thing to answer, the status line says so ("Finding your location. If your
   device asks, allow it.") and the pin lands when the device answers. A refusal, a
   timeout or an unsupported browser shows a calm line pointing at the search and the
   map; "Use my location" (a small control over the map, next to the satellite
   toggle, disabled and `aria-busy` while a request is pending) asks again. An
   automatic answer never replaces a pin placed while it was pending. The search
   form submits to `GET /places?q=` and renders `places/_results` into the
   `place-results` frame (a listbox of up to five results from
   `Geocoding::Client#search`); picking one, or the device position, moves the
   Leaflet pin (`vendor/javascript/leaflet.js`, OpenStreetMap tiles with a satellite
   toggle on Esri World Imagery, tap to move, arrow keys nudge). The native shells
   do not yet grant web geolocation (no location usage key on iOS, no
   `onGeolocationPermissionsShowPrompt` on Android), so inside the apps the
   automatic attempt fails and the search and the map carry the step. "This is my field"
   loads `GET /places/reverse?lat&lon` into the `place-summary` frame: place label,
   region, country code and the coordinates. Both frames answer 200 with a calm
   line when the geocoder fails or the `geocoding` switch is paused. Nothing is
   fetched from the browser except map tiles (images).
2. **Basics.** Crop now (a `<datalist>` from `Crops::Catalog`, free text allowed),
   rainfed or irrigated, an optional area with a unit that defaults from the
   country (`US`, `LR`, `MM` → acres). The crop text is normalised at save time by
   `Crops::NormalizeService`: the catalog first (about 60 crops with English and
   Spanish names and aliases, accent-insensitive), otherwise one structured Gemini
   call (`crop_name`, `scientific_name`, `confidence`), falling back to the raw text.
3. **Save.** Signed out: two equal cards, "Use your face or fingerprint" (the passkey ceremony, `passkey_controller.js`) and "Email me a code" (`SignInCodesController`, `docs/AUTH.md`; the card expands by default where passkeys are unsupported); with the passkey card, a name and the ceremony;
   the form's flat hidden inputs (`latitude, longitude, place_label, country_code,
   admin_area, location_source, crop_name, irrigation, area, area_unit, locale`) are
   posted as a flat JSON map, parked in `session[:registration]["field"]` by
   `RegistrationsController#options` (coerced with `Onboarding::Allowlist.coerce`
   and the enums) and written by `Fields::SaveSetupService` inside the sign-up
   transaction; the answer redirects to `/app`. Signed in: `PATCH /app/fields/:id`
   through the same service.

`Fields::SaveSetupService` writes the main field (pin, `location_confidence:
confirmed`, place label, area, unit, irrigation), the farm's country and region, a
`field_crops` row for the current season (`source: farmer`), the profile's units,
and completes the onboarding session, so nothing anywhere forces the chat.

## Ask Aluni (`/app/onboarding`)

The chat is reachable from the home page only. Gemini drafts every line Aluni
says; the app filters what it extracts, applies it right away and offers an Undo
toast; the conversation moves through `welcome -> crops -> soil -> goals ->
summary` (`config/onboarding/topics.yml`), and the system prompt carries the
field basics settled during setup so they are never asked again. The engine lives
in `app/services/onboarding/` and is described below.

### One turn, in order (`Onboarding::ReplyService`)

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
   bounded by `gemini_timeout`; a classifier that has not finished counts as safe.
5. Unsafe: a strike, the draft is thrown away, Aluni answers with
   `onboarding.refusals.<abuse_type>` (`refusal: true`). At `strike_limit`
   strikes the row is blocked for `block_ttl` and the answer is `onboarding.blocked`.
6. Draft failed (Gemini down, bad JSON, or the `gemini` switch paused): Aluni
   answers with a continuation line (`onboarding.continuations.<topic>`, rotated
   by `fallbacks_count`), the message is kept in `pending_message` and replayed
   into the next request (`degraded: true`).
7. Otherwise the answer's `updates` go through the allowlist and are applied at
   once (`ApplyProposalService`, which captures the previous values); the result is
   stored in `session.last_applied` and returned as `applied:` for the toast. A
   failed apply is logged, the proposal stays staged on the row, and the turn still
   answers. When `topic_complete` is true the topic advances, or on the last topic
   `CompleteService` closes the session and stores the segment.

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

`coords` is `{ latitude:, longitude: }` from the browser's share-location button
(strings or numbers; out-of-range values are ignored).

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
`geolocation`) or from a `location_guess` with confidence `medium` or `high`
(approximate, `assistant`, with `place_label`). The browser pin wins over a guess.

## Auto-apply and Undo

`ApplyProposalService.call(user:, accepted:)` reads the proposal from the row (never
from the request), keeps the accepted keys (`Allowlist.keys_for(proposal)`: the pin
counts once, as `field.latitude`), filters again, and writes profile, farm, main
field (soil merged into the existing hash) and crops (upserted by
`[field_id, season_year, role]`, `source: "assistant"`) in one transaction. Before
writing it captures `before`: the attribute slices it is about to change, the old
soil hash, and per crop either `"new_record" => true` or the old attributes. It
returns `Success(applied:, before:)`; `ReplyService` stores
`{ "before" => ..., "applied" => ..., "at" => iso8601 }` in
`onboarding_sessions.last_applied` and the stream shows a toast ("Saved: area 12.5
hectares, irrigation drip." built by `OnboardingHelper#applied_summary`) with an
Undo button. `UndoApplyService.call(user:)` restores `before` in one transaction
(new crops destroyed, old attributes put back), clears `last_applied` and answers
`Success(restored:)`; with nothing to undo it is `Failure(code: :nothing_to_undo)`.
Only the latest apply can be undone, so the toast slot is replaced, never appended.

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

## Accessibility

- Language first: the page is already in the browser language; the first bubble only offers the other one, and the chips reload the page in that language with the same bubble.
- Comfort choices (text size, read aloud, less motion, high contrast) are one tap each, apply instantly, persist for every visit (cookie, then the account) and are repeated by the small nav buttons from 641 px.
- Read aloud is the browser voice (`speech:read`); every new Aluni line and every finder step is spoken when it is on; nothing ever waits on speech.
- Less motion by choice behaves like the OS setting: the mascot skips the centre and the walk, the hero shows its CSS backdrop, nothing animates in (`reducedMotion()` everywhere).
- Keyboard: every control is a real button, link or form field with a visible focus ring; the finder moves focus to each step heading, Escape closes it, arrow keys nudge the map pin, and the search box and "Use my location" (over the map) are the keyboard paths around the map; the automatic location request announces its progress and its outcome through the status line.
- Screen readers: the bubble is a labelled dialog, the finder steps announce through `aria-live`, map tiles are decorative and the place summary is text.
- 48 px targets, `min-width` queries, both themes and high contrast checked at 390, 768, 1024 and 1400 px.

## Demo runbook

1. A configured Gemini backend (development: `gemini.api_key` in the credentials; production: `GEMINI_BACKEND=vertex` with `GOOGLE_CLOUD_PROJECT`) and `mise exec -- bin/rails 'platform:resume[gemini]'`; without it the crop normaliser falls back to the typed text and Ask Aluni answers with continuation lines.
2. `mise exec -- bin/dev`, open `http://localhost:3000` (a secure context: passkeys and the share-location button need one; a phone needs an https tunnel with `APP_DOMAIN`, `docs/AUTH.md`). A browser set to Spanish lands on `/es` with the Spanish bubble.
3. Watch Aluni sprout in the centre and settle in the corner; pick a language, switch on read aloud and larger text, press "Looks good".
4. "Find my field": the location prompt appears on its own; allow it (or search "Ames, Iowa"), drag the pin, confirm, type "papa criolla" as the crop (it becomes Solanum tuberosum at save), choose irrigated, enter 12 hectares, give a name and create the passkey; land on `/app`.
5. Reload the landing: no intro, Aluni goes straight to "Let's find your field". Open Ask Aluni from the home page, say "I rotate with beans every other year", see the toast and press Undo.
6. `platform:pause[geocoding]` shows the calm fallback in the finder; `platform:pause[gemini]` shows the continuation lines.

## Phase 2 candidates

A field boundary on the map (`fields.boundary`); the first data fetches (NASA POWER climatology, SSURGO and CDL for US pins, GAEZ suitability) behind switchboard-guarded clients; crop cards built from ECOCROP, FAO-56 and GAEZ ("the optimal environment for potatoes"); progressive questions inside the app reusing the Ask Aluni engine; the real `/app` home; a welcome notification through `NotificationRouter`.
