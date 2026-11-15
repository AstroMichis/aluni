# /auth -- Passkeys, sessions and the native gate

You are changing authentication for Aluni. The request is: $ARGUMENTS

## Before writing code:

1. Read `docs/AUTH.md` completely
2. Read `app/controllers/concerns/{authentication,native_only,passkey_ceremony}.rb`
3. Read `app/controllers/{sessions,registrations,passkeys}_controller.rb` and `app/javascript/controllers/passkey_controller.js`
4. Read `spec/requests/passkey_flow_spec.rb` and `spec/support/passkeys.rb`
5. Read `config/initializers/webauthn.rb` and `config/initializers/native.rb`

## Non-negotiable rules

- **No passwords, ever.** No `has_secure_password`, no bcrypt, no Devise, no JWT, no magic links as a primary factor.
- **The webauthn gem does the cryptography.** Never parse CBOR, verify signatures or compare challenges by hand. `WebAuthn::Credential.options_for_create/options_for_get`, `from_create/from_get`, `verify`.
- **Discoverable, user-verified credentials.** `resident_key: "required"`, `user_verification: "required"`; sign-in sends an empty `allowCredentials`.
- **Challenges live in the cookie session for one ceremony** (`session[:authentication_challenge]`, `session[:registration]`, `session[:creation_challenge]`) and are deleted when consumed.
- **Sessions are rows.** `start_new_session_for(user)` creates a `Session` and sets the permanent signed cookie; `terminate_session` destroys it. Never store user data in the cookie.
- **Every new authenticated controller inherits `App::BaseController`** (session + the `NativeOnly` kill switch); every new ceremony endpoint includes `NativeOnly` and `PasskeyCeremony` and goes through `with_ceremony`.
- **RP id and origins come from `config.x.webauthn`** per environment; never hardcode a host.
- **Errors are JSON codes**, mapped to copy in `passkeys.errors.*` (both locales). Never leak gem exception messages to a person.
- **Rack::Attack throttles the ceremonies** (`RACK_ATTACK_AUTH_PATH`); update the regex when you add an auth path.

## Adding an auth-related endpoint

1. Route inside `scope "(:locale)"` (or `namespace :app` when it needs a session)
2. Controller: `include NativeOnly`, `include PasskeyCeremony` if it runs a ceremony; `allow_unauthenticated_access` only for the sign-in/sign-up steps
3. View with `data-controller="passkey"`, `data-passkey-mode-value` (`create` | `get`), `data-passkey-options-url-value`, `data-passkey-submit-url-value`, `data-passkey-messages-value="<%= passkey_messages %>"`
4. Locale keys under the controller path in `en` and `es`
5. Request spec with `fake_authenticator` (register with `client.create(challenge:, user_verified: true)`, sign in with `client.get(challenge:, user_verified: true, user_handle: WebAuthn.standard_encoder.decode(user.webauthn_id))`), plus the native gate and the throttle

## Native shells

The web views run the ceremony themselves: iOS needs `webcredentials:aluni.us` in the Release entitlements and the AASA `webcredentials` entry; Android needs `AluniWebView` (WebAuthn support on) and `assetlinks.json` with `get_login_creds`. A native Credential Manager bridge for older Android posts the same JSON to the same endpoints; add its `android:apk-key-hash:` origin to `allowed_origins` when it exists. See `docs/NATIVE.md`.

## Development

`localhost:3000` (secure context; browsers are first-class clients, `NATIVE_WEB_ACCESS=0` would close them), `adb reverse tcp:3000 tcp:3000` for the Android emulator. A passkey created against `localhost` never works against `aluni.us`.

## Testing

`mise exec -- bundle exec rspec spec/requests/passkey_flow_spec.rb spec/requests/native_only_spec.rb spec/controllers/api/v1/base_controller_spec.rb spec/requests/rack_attack_spec.rb`
