# Data model

Infrastructure tables first, then the product tables the onboarding chat fills (`docs/ONBOARDING.md`). Follow the conventions at the end.

| Table | Purpose | Notable columns |
|---|---|---|
| `users` | An account (passkeys only) | `webauthn_id` (unique, opaque WebAuthn user handle), `display_name`, `email_address` (nullable, unique when present), `locale`, `email_verified_at` (set when a code proved the address), `preferences` (jsonb, the allowlisted comfort choices of `Preferences`: theme, text_size, motion, contrast, read_aloud, seen_welcome; the `aluni_prefs` cookie carries the same for visitors) |
| `passkeys` | One WebAuthn credential of a user | `external_id` (unique credential id), `public_key` (COSE, base64url), `sign_count`, `nickname`, `transports` (string array), `last_used_at` |
| `sessions` | One signed-in device | `user_id`, `ip_address`, `user_agent`, `sign_in_method` (passkey or email_code); `updated_at` is "last seen" |
| `platform_switches` | Operator pause flags | `service` (unique, one of `PlatformSwitch::SERVICES`), `paused`, `paused_by`, `reason` |
| `device_tokens` | Native push tokens from the shells | `user_id`, `token`, `platform` (enum ios 0, android 1); unique `(token, platform)` |
| `action_push_native_devices` | The gem's device table, mirrored from `device_tokens` by `Notifications::PushDevices` | `owner` (polymorphic), `platform` (apple/google), `token`; unique `(platform, token)` |
| `web_push_subscriptions` | Browsers that agreed to Web Push | `user_id`, `endpoint`, `p256dh`, `auth`, `user_agent`, `last_used_at`; unique `(user_id, endpoint)` |
| `sign_in_codes` | One emailed (later texted) sign-in code (`docs/AUTH.md`) | `channel` (email 0, sms 10), `destination` (normalised address), `code_digest` (HMAC, never the code), `expires_at`, `attempts`, `consumed_at`, `verified_at`, `used_at`, `requester_ip`, `locale`, `pending` (jsonb: display_name, locale, the finder's field); index `(destination, created_at)`; purged after a day |
| `notification_deliveries` | One `NotificationRouter.deliver` call | `purpose`, `recipient` (polymorphic), `idempotency_key` (unique), `status` (enum queued 0, sent 1, skipped 2, failed 3), `channel`, `sent_at`, `provider_message_id`, `attempts` (jsonb), `failed_reason` |
| `field_observations` | What one public data source returned for a field's pin (`Fields::FetchObservationsJob`) | `field_id`, `source` (fcc, nasa_power, gaez, ssurgo, usgs_elevation, cdl), `status` (enum ok 0, empty 10, out_of_coverage 20, failed 30), `payload` (jsonb), `error`, `fetched_at`; unique `(field_id, source)` |

Associations: `User has_many :sessions, :passkeys, :device_tokens, :web_push_subscriptions` and `:notification_deliveries (as: :recipient)`, all `dependent: :destroy`.

## Product tables

Every data source in `docs/DATA_SOURCES.md` needs only a lat/lon point, so a field carries a pin; a boundary polygon waits for a map (Phase 2). Soil is asked in ECOCROP classes because no global soil source is documented. Enums start at `unknown` (0) and are prefixed (`irrigation_rainfed?`) because the values repeat across columns; none is ever named `none`, which would collide with `ActiveRecord::QueryMethods#none`.

| Table | Purpose | Notable columns |
|---|---|---|
| `farmer_profiles` | Who the farmer is and how they work (one per user) | enums `role`, `experience`, `team`, `units` (metric 0, imperial 10), `land_tenure`, `budget_level` (low/high, the GAEZ input level), `risk_tolerance`, `segment` (smallholder_subsistence 10, small_commercial 20, mid_mechanized 30, large_commercial 40); `team_size`; jsonb lists `goals` (ranked), `equipment`, `livestock`, `market_channels`, `practices`, each validated against the constant on the model by `JsonAllowlistValidator`; `notification_preferences` (jsonb hash); `notes` |
| `farms` | Groups fields; one is created implicitly | `user_id`, `name`, `country_code` (ISO 2, normalised upper case), `admin_area`; both location columns are derived from a pin later, never asked |
| `fields` | One parcel | `farm_id`, `name`, `position`, `latitude`/`longitude` (decimal 9,6), `location_confidence` (approximate 10, confirmed 20), `location_source` (geolocation 10, typed 20, assistant 30, map 40), `place_label`, `boundary` (GeoJSON jsonb, empty until Phase 2), `area` + `area_unit` (hectares 0, acres 10), `irrigation` (rainfed 10, irrigated 20, drip 30, sprinkler 40, pivot 50, gravity 60, other 70), `water_source` (rain 10, well 20, river_canal 30, reservoir 40, mixed 50), `cropping_intensity` (one_per_year 10, two_per_year 20, continuous 30), `soil` (jsonb: texture, depth, drainage, salinity, fertility, problems[] from `Field::SOIL`; free `ph`, `lab_test`, `notes`); index `(farm_id, position)` |
| `field_crops` | One crop in one season on one field | `field_id`, `crop_name`, `scientific_name`, `crop_key` (slug of the scientific name, else the common name), `season_year`, `planting_month`/`harvest_month` (1-12), `role` (main 0, second 10, cover 20, intercrop 30), `source` (farmer 0, cdl 10, assistant 20), `share` (decimal 0-1, the part of the field; null = the whole field) and `cells` (integer[] on the 10x10 field map, `FieldCrop::GRID`; empty = the whole field); a season may split a field between crops (crop zones); unique `(field_id, season_year, role, crop_key)` |
| `onboarding_sessions` | The state of one person's onboarding chat (one per user) | `topic` (a key from `config/onboarding/topics.yml`), `status` (active 0, completed 10), `completed_at`, `transcript` (text, `serialize coder: JSON` then `encrypts`; always read as an array, assign a new array to change it), `proposal` (jsonb, staged only when an automatic apply failed), `last_applied` (jsonb `{ before:, applied:, at: }`, what the Undo toast restores), `pending_message` (encrypted), `fallbacks_count`, `turns_count`, `strikes`, `blocked_until`, `language`, `last_message_at` |

Associations: `User has_one :farmer_profile, has_one :onboarding_session, has_many :farms`; `Farm has_many :fields` (ordered by `position`); `Field has_many :field_crops`; all `dependent: :destroy`. `User#onboarding_complete?` reads the session status. `Onboarding::EnsureProfileService` creates the profile, one farm with one field and the session idempotently; `Onboarding::ProfileSnapshot` is the one read model over all of them (`#to_h` for the preview, `#to_prompt` for the system prompt, `#required_known?` for topic completion).

The conversation lives in Postgres, not Redis: a refresh or a day away resumes, and Active Record encryption covers "encrypted at rest". `OnboardingSession` is listed in `ENCRYPTED_MODELS` (`lib/tasks/encryption.rake`).

## Conventions

- Always `rails generate migration`; `null: false` on required columns; defaults where sensible.
- Integer-backed enums with `default: 0, null: false` (`enum :status, { queued: 0, sent: 1 }`), with gaps when values will be inserted later.
- `jsonb` with a default (`{}` or `[]`) for flexible data; string arrays for small lists (`transports`).
- Money as integer minor units or `decimal precision: 10, scale: 2`; never Float. Currency USD by default.
- Sensitive columns use `encrypts` (Active Record encryption; keys guarded at boot by `lib/active_record_encryption_check.rb`). Add the model to `ENCRYPTED_MODELS` in `lib/tasks/encryption.rake` when encrypting an existing column, run `encryption:backfill`, then set `AR_ENCRYPTION_SUPPORT_UNENCRYPTED_DATA=false`.
- Indexes for every column in a `WHERE` or `ORDER BY`; unique indexes for natural keys; partial indexes where the column is nullable (`email_address`).
- Model structure order: associations, enums, encrypts, scopes, validations, callbacks, public methods, private methods. State transitions as `can_x?` guards and `x!` methods.
- `db/schema.rb` is the source of truth for the test database (`db:schema:load` in CI); production migrates once per deploy from `.kamal/hooks/pre-deploy`.
