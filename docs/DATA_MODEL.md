# Data model

The shell holds only the infrastructure tables. Product tables arrive with the product; follow the conventions at the end.

| Table | Purpose | Notable columns |
|---|---|---|
| `users` | An account (passkeys only) | `webauthn_id` (unique, opaque WebAuthn user handle), `display_name`, `email_address` (nullable, unique when present), `locale` |
| `passkeys` | One WebAuthn credential of a user | `external_id` (unique credential id), `public_key` (COSE, base64url), `sign_count`, `nickname`, `transports` (string array), `last_used_at` |
| `sessions` | One signed-in device | `user_id`, `ip_address`, `user_agent`; `updated_at` is "last seen" |
| `platform_switches` | Operator pause flags | `service` (unique, one of `PlatformSwitch::SERVICES`), `paused`, `paused_by`, `reason` |
| `device_tokens` | Native push tokens from the shells | `user_id`, `token`, `platform` (enum ios 0, android 1); unique `(token, platform)` |
| `action_push_native_devices` | The gem's device table, mirrored from `device_tokens` by `Notifications::PushDevices` | `owner` (polymorphic), `platform` (apple/google), `token`; unique `(platform, token)` |
| `web_push_subscriptions` | Browsers that agreed to Web Push | `user_id`, `endpoint`, `p256dh`, `auth`, `user_agent`, `last_used_at`; unique `(user_id, endpoint)` |
| `notification_deliveries` | One `NotificationRouter.deliver` call | `purpose`, `recipient` (polymorphic), `idempotency_key` (unique), `status` (enum queued 0, sent 1, skipped 2, failed 3), `channel`, `sent_at`, `provider_message_id`, `attempts` (jsonb), `failed_reason` |

Associations: `User has_many :sessions, :passkeys, :device_tokens, :web_push_subscriptions` and `:notification_deliveries (as: :recipient)`, all `dependent: :destroy`.

## Conventions

- Always `rails generate migration`; `null: false` on required columns; defaults where sensible.
- Integer-backed enums with `default: 0, null: false` (`enum :status, { queued: 0, sent: 1 }`), with gaps when values will be inserted later.
- `jsonb` with a default (`{}` or `[]`) for flexible data; string arrays for small lists (`transports`).
- Money as integer minor units or `decimal precision: 10, scale: 2`; never Float. Currency USD by default.
- Sensitive columns use `encrypts` (Active Record encryption; keys guarded at boot by `lib/active_record_encryption_check.rb`). Add the model to `ENCRYPTED_MODELS` in `lib/tasks/encryption.rake` when encrypting an existing column, run `encryption:backfill`, then set `AR_ENCRYPTION_SUPPORT_UNENCRYPTED_DATA=false`.
- Indexes for every column in a `WHERE` or `ORDER BY`; unique indexes for natural keys; partial indexes where the column is nullable (`email_address`).
- Model structure order: associations, enums, encrypts, scopes, validations, callbacks, public methods, private methods. State transitions as `can_x?` guards and `x!` methods.
- `db/schema.rb` is the source of truth for the test database (`db:schema:load` in CI); production migrates once per deploy from `.kamal/hooks/pre-deploy`.
