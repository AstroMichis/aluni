# Authentication: passkeys only

Aluni has no passwords. A person creates an account with a display name (email optional) and the first passkey; later they sign in with that passkey (face, fingerprint or device code). The server side is Rails 8 built-in authentication (sessions as rows, a permanent signed cookie) plus the `webauthn` gem; the browser side is one Stimulus controller.

## Pieces

| Where | What |
|---|---|
| `app/models/user.rb` | `webauthn_id` (opaque WebAuthn user handle, `WebAuthn.generate_user_id`), `display_name`, optional `email_address`, `locale` |
| `app/models/passkey.rb` | One row per credential: `external_id`, `public_key` (COSE, base64url), `sign_count`, `nickname`, `transports`, `last_used_at` |
| `app/models/session.rb` | One row per signed-in device; `updated_at` is "last seen" (touched at most daily) |
| `app/controllers/concerns/authentication.rb` | `require_authentication`, `resume_session`, `start_new_session_for`, `terminate_session`, `after_authentication_url` |
| `app/controllers/concerns/passkey_ceremony.rb` | Shared ceremony pieces: permitted credential params, `with_ceremony` error handling, authenticator selection |
| `app/controllers/concerns/native_only.rb` | The soft gate: native shells only unless `NATIVE_WEB_ACCESS=1` |
| `SessionsController` | `new`, `options` (challenge, empty allow list), `create` (verify assertion, open session), `destroy` |
| `RegistrationsController` | `new`, `options` (mint user handle, park pending account in the session), `create` (verify attestation, create User + Passkey) |
| `PasskeysController` | List, add (excluding existing credentials), remove (never the last one) |
| `Api::V1::BaseController` | Same session cookie for JSON; `X-Aluni-Native: 1` replaces CSRF on writes |
| `app/javascript/controllers/passkey_controller.js` | Fetches options, runs `navigator.credentials.create/get`, posts the credential, follows `redirect_to` |
| `config/initializers/webauthn.rb` | `allowed_origins`, `rp_id` and `rp_name` from `config.x.webauthn` (per environment) |

## The ceremonies

Sign-up: `POST /sign_up/options` with `display_name` (and optional `email_address`) answers `PublicKeyCredentialCreationOptions` (JSON, base64url fields) with `residentKey: required` and `userVerification: required`; the pending account and challenge are parked in the cookie session. `POST /sign_up` with the browser's `PublicKeyCredential.toJSON()` verifies the attestation, creates the user and passkey in one transaction, opens a session and answers `{ redirect_to }` (201).

Sign-in: `POST /sign_in/options` answers request options with an empty `allowCredentials` (discoverable credential: the authenticator offers the person's passkeys, nothing to type). `POST /sign_in` finds the passkey by credential id, checks the user handle, verifies the assertion against the stored public key and sign count, records usage, opens the session, answers `{ redirect_to }`.

Failures answer JSON: 400 for a malformed credential, 401 `unknown_credential`, 422 `verification_failed` (with a stable `code`), 422 `registration_expired`, `display_name_required`, `too_long`, `invalid`. The Stimulus controller maps codes to i18n strings (`passkeys.errors.*`). Rack::Attack limits ceremonies to 8 POSTs per minute per IP.

## Relying party id and origins

A passkey is bound to its RP id, so development and production credentials are separate.

| Env | `rp_id` | `allowed_origins` |
|---|---|---|
| development | `localhost` | `http://localhost:3000` |
| test | `www.example.com` | `http://www.example.com` |
| production | `APP_DOMAIN` (aluni.us) | `https://aluni.us`, `https://www.aluni.us` |

WebAuthn requires a secure context. `localhost` is the only plain-http origin browsers accept, which is why development runs on `localhost:3000` (not `lvh.me`, not the Android emulator's `10.0.2.2`). The iOS simulator shares the Mac's localhost. For the Android emulator run `adb reverse tcp:3000 tcp:3000` so the device's `localhost:3000` reaches the Mac.

## Passkeys inside the native shells

- **iOS (WKWebView)** runs the ceremony itself once the app's associated domains include `webcredentials:aluni.us` (Release entitlements) and the server's `apple-app-site-association` lists the app under `webcredentials` (`AppLinksController`). No Swift code.
- **Android (WebView)** needs `WebSettingsCompat.setWebAuthenticationSupport(..., WEB_AUTHENTICATION_SUPPORT_FOR_APP)` (`android/.../AluniWebView.kt`) and `assetlinks.json` with the `delegate_permission/common.get_login_creds` relation. Google grants it on Android 14+ WebViews; older devices get the page's "unsupported" message until a native Credential Manager bridge component exists (same server endpoints, see `docs/NATIVE.md`).

## The native gate

`NativeOnly` redirects browsers to the informational site with a notice; JSON requests get 403. It is a product gate (a user-agent check), not a security boundary: the session cookie and the ceremony are the boundary. `Platform::Features.native_web_access?` (ENV `NATIVE_WEB_ACCESS`) opens the pages to browsers; development defaults to on, test and production to off. Specs use `with_native_web_access(true)` or send `native_headers`.

## Sign-ups

`SIGNUPS_ENABLED=0` closes account creation while sign-in stays open (`ensure_signups_open`, `signups_enabled?` in views).

## Specs

`spec/requests/passkey_flow_spec.rb` drives the whole flow with `WebAuthn::FakeClient` (origin `http://www.example.com`): register, use `/app`, sign out, sign in again, replay rejected, unknown credential rejected, passkey management. `spec/requests/native_only_spec.rb` covers the gate; `spec/controllers/api/v1/base_controller_spec.rb` the API header rule; `spec/requests/rack_attack_spec.rb` the throttle.

## Notes

- Synced passkeys (iCloud Keychain, Google Password Manager) report `sign_count` 0 forever; the gem accepts 0 to 0, so no false failures.
- `Sessions::PurgeStaleJob` (daily) deletes sessions unused for a year.
- `allow_browser versions: :modern` skips the native shells so an old Android System WebView is not answered with 406.
