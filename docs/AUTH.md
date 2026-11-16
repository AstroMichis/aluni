# Authentication: passwordless, by passkey or emailed code

Aluni has no passwords. A person creates an account with a display name and either a passkey or a code sent to their email; later they sign in with that passkey (face, fingerprint or device PIN) or with a fresh emailed code. The server side is Rails 8 built-in authentication (sessions as rows, a permanent signed cookie) plus the `webauthn` gem and the sign-in code services; the browser side is two Stimulus controllers (`passkey`, `sign-in-code`) and the `choice` controller that lets the person pick between them.

## Pieces

| Where | What |
|---|---|
| `app/models/user.rb` | `webauthn_id` (opaque WebAuthn user handle, `WebAuthn.generate_user_id`), `display_name`, optional `email_address`, `locale` |
| `app/models/passkey.rb` | One row per credential: `external_id`, `public_key` (COSE, base64url), `sign_count`, `nickname`, `transports`, `last_used_at` |
| `app/models/session.rb` | One row per signed-in device; `updated_at` is "last seen" (touched at most daily) |
| `app/controllers/concerns/authentication.rb` | `require_authentication`, `resume_session`, `start_new_session_for`, `terminate_session`, `after_authentication_url` |
| `app/controllers/concerns/passkey_ceremony.rb` | Shared ceremony pieces: permitted credential params, `with_ceremony` error handling, authenticator selection |
| `app/controllers/concerns/native_only.rb` | The kill switch: `NATIVE_WEB_ACCESS=0` closes sign-in and `/app` to browsers, shells keep working |
| `SessionsController` | `new`, `options` (challenge, empty allow list), `create` (verify assertion, open session), `destroy` |
| `RegistrationsController` | `new`, `options` (mint user handle, park pending account in the session), `create` (verify attestation, create User + Passkey) |
| `PasskeysController` | List, add (excluding existing credentials), remove (never the last one) |
| `Api::V1::BaseController` | Same session cookie for JSON; `X-Aluni-Native: 1` replaces CSRF on writes |
| `app/javascript/controllers/passkey_controller.js` | Fetches options, runs `navigator.credentials.create/get`, posts the credential, follows `redirect_to` |
| `config/initializers/webauthn.rb` | `allowed_origins`, `rp_id` and `rp_name` from `config.x.webauthn` (per environment) |

## The ceremonies

Sign-up: `POST /sign_up/options` with `display_name` (and optional `email_address`) answers `PublicKeyCredentialCreationOptions` (JSON, base64url fields) with `residentKey: required` and `userVerification: required`; the pending account and challenge are parked in the cookie session. `POST /sign_up` with the browser's `PublicKeyCredential.toJSON()` verifies the attestation, creates the user and passkey in one transaction, opens a session and answers `{ redirect_to }` (201). The options request may carry `locale` (en or es, from the landing chat's language step); it is parked with the pending account, becomes the user's locale and the locale cookie, and `redirect_to` points at `/app/onboarding` in that locale. The same request may carry the field finder's flat keys (`latitude, longitude, place_label, country_code, admin_area, location_source, crop_name, irrigation, area, area_unit`; the passkey controller posts every input of its form as a flat JSON map, so the names are flat on purpose): `Fields::SaveSetupService.coerce` validates them, `options` parks them as `session[:registration]["field"]`, and `create` writes farm, field, crop and profile through `Fields::SaveSetupService` inside the account transaction (a failure there is logged and never blocks the account). Any form with hidden `display_name` and `locale` inputs can drive the ceremony through `passkey_controller.js`; the finder's save step is that form.

Sign-in: `POST /sign_in/options` answers request options with an empty `allowCredentials` (discoverable credential: the authenticator offers the person's passkeys, nothing to type). `POST /sign_in` finds the passkey by credential id, checks the user handle, verifies the assertion against the stored public key and sign count, records usage, opens the session, answers `{ redirect_to }`.

Failures answer JSON: 400 for a malformed credential, 401 `unknown_credential`, 422 `verification_failed` (with a stable `code`), 422 `registration_expired`, `display_name_required`, `too_long`, `invalid`. The Stimulus controller maps codes to i18n strings (`passkeys.errors.*`). Rack::Attack limits ceremonies to 8 POSTs per minute per IP.

## Relying party id and origins

A passkey is bound to its RP id, so development and production credentials are separate.

| Env | `rp_id` | `allowed_origins` |
|---|---|---|
| development | `APP_DOMAIN`, default `localhost` | `http://localhost:3000`, or `https://<APP_DOMAIN>` when it is set |
| test | `www.example.com` | `http://www.example.com` |
| production | `APP_DOMAIN` (aluni.us) | `https://aluni.us`, `https://www.aluni.us` |

WebAuthn requires a secure context. `localhost` is the only plain-http origin browsers accept, which is why development runs on `localhost:3000` (not `lvh.me`, not the Android emulator's `10.0.2.2`). The iOS simulator shares the Mac's localhost. For the Android emulator run `adb reverse tcp:3000 tcp:3000` so the device's `localhost:3000` reaches the Mac.

A phone that reaches the Mac by its LAN address (`http://172.20.10.3:3000`) is not a secure context: the page shows `passkeys.errors.insecure` and the ceremony never starts. To try passkeys from a phone, run `bin/dev` behind an https tunnel (cloudflared, ngrok) and start it with `APP_DOMAIN=<tunnel host>`; the RP id, the allowed origin and the host allow-list follow, and the phone's own browser can sign in. Passkeys created for a tunnel host belong to that host name.

## Passkeys inside the native shells

- **iOS (WKWebView)** runs the ceremony itself once the app's associated domains include `webcredentials:aluni.us` (Release entitlements) and the server's `apple-app-site-association` lists the app under `webcredentials` (`AppLinksController`). No Swift code. Until then the shell cannot sign in: Debug builds carry no entitlements and a free Personal Team cannot provision Associated Domains, so WKWebView refuses the ceremony even over https. With the paid team, a Debug entitlements file can carry `webcredentials:<development host>?mode=developer` (Associated Domains Development switched on in the device's Developer settings) against a tunnel started with `APP_DOMAIN`.
- **Android (WebView)** needs `WebSettingsCompat.setWebAuthenticationSupport(..., WEB_AUTHENTICATION_SUPPORT_FOR_APP)` (`android/.../AluniWebView.kt`) and `assetlinks.json` with the `delegate_permission/common.get_login_creds` relation. Google grants it on Android 14+ WebViews; older devices get the page's "unsupported" message until a native Credential Manager bridge component exists (same server endpoints, see `docs/NATIVE.md`).

## The web kill switch

Browsers and the native shells are both clients. `NativeOnly` (on `SessionsController`, `RegistrationsController`, `PasskeysController` and `App::BaseController`) does nothing while `Platform::Features.native_web_access?` is true, the default in every environment (ENV `NATIVE_WEB_ACCESS`, read in `config/initializers/native.rb`). Set `NATIVE_WEB_ACCESS=0` to close the browser side: browsers are sent to the landing page with a notice and JSON requests get 403, while the shells (turbo-rails' `hotwire_native_app?`, a user-agent check) keep working. It is a product switch, not a security boundary: the session cookie and the ceremony are the boundary. Specs use `with_native_web_access(false)` to exercise the closed state and `native_headers` to act as a shell.

## The emailed code (`SignInCodesController`, `app/services/auth/`)

The second way in, for people who find the passkey prompt unfamiliar or whose device cannot show it. One flow for sign-in and sign-up, so the server never says whether an address has an account: `POST /sign_in/code` with `email` (plus `display_name`, `locale` and the finder's flat field keys on a sign-up) runs `Auth::RequestCodeService`, which creates a `sign_in_codes` row (the code stored as an HMAC over `destination:code` with a key from `Rails.application.key_generator`, ten minutes, older live rows for the address superseded, the parked details in `pending`), sends `SignInMailer#code` inline (`deliver_now`: a code cannot wait for a queue) and parks the row id in the cookie session. The mail carries the six digits and a link (`GET /sign_in/link?token=`, a signed `message_verifier` token with the same expiry; the token sits in the query so logs filter it). `POST /sign_in/code/verify` runs `Auth::VerifyCodeService` under a row lock: attempts count before the comparison (`SignInCode::MAX_ATTEMPTS` five), `secure_compare` on the digests, one use. A proven code then finds the account behind the address: it exists → session with `sign_in_method: "email_code"` and `email_verified_at` set (an address typed at a passkey sign-up was never verified, so proof wins the account carrying it; logged); it does not exist → `Auth::CreateAccountService` with the parked or just-typed name (`POST /sign_in/code/complete`) and the finder's field, or `signups_closed` when sign-ups are off (checked only after proof). The link signs in only in the browser that asked (the cookie session holds the row id); anywhere else it shows the code to type back. `POST /sign_in/code/resend` waits `RESEND_AFTER` (60 s). Every answer is a Turbo Stream that replaces the `auth` frame (the finder, `/sign_in` and `/sign_up` host one) or the full page without JavaScript; successes redirect the whole page (`data-turbo-frame="_top"`).

Guards: `codes/email` (5 per address per 15 min), `codes/ip` (10), `verify/ip` (20) and `auth/ip` in Rack::Attack; the `mail` switch (`Platform::Switchboard.guard!(:mail)`) and `Platform::Features.mail?` hide or refuse the option calmly; `SignInCodes::PurgeJob` deletes rows after a day; `sessions.sign_in_method` records how each session started. After a code sign-in the person is invited once (a toast) to add a passkey from `/passkeys`; `PasskeysController#destroy` lets the last passkey go when the address is verified.

## Google, Apple and Microsoft (`OmniauthCallbacksController`, `config/initializers/omniauth.rb`)

A third way in beside passkeys and emailed codes, web only for now.

- **Providers appear once their credentials exist** (`oauth.google.client_id/client_secret`, `oauth.apple.client_id/team_id/key_id/private_key`, `oauth.microsoft.client_id/client_secret`); `ApplicationHelper#social_providers` lists them in the order Google, Apple, Microsoft and hides them in the native shells, when browsers are shut out (`NativeOnly`) and while the `oauth` switch is paused.
- **The buttons** (`sign_in_codes/_social`, under the two cards on `/sign_in`, `/sign_up` and the finder's save step) are plain POST forms to OmniAuth's request phase (`/auth/:provider`, CSRF-checked by omniauth-rails_csrf_protection), outside Turbo. In the finder they carry the finder's hidden field inputs; `OmniAuth.config.before_request_phase` keeps those, the language and `intent` (sign_in or connect) in `session["oauth_pending"]`.
- **The callback** (`/auth/:provider/callback`, CSRF skipped: OmniAuth's state is the check) hands the auth hash to `Auth::SocialSignInService`: a linked account signs in; a verified Google or Apple address that belongs to an account links and signs in ("proof wins", as with the code); an unverified one (Microsoft's always) is refused, never linked; otherwise a new account, with the finder's field. Sessions record the provider as `sign_in_method` (`google_oauth2`, `apple`, `microsoft_graph`). No provider token is kept.
- **Apple** answers with a cross-site form POST that carries no SameSite=Lax cookie, so its registered return URL is `https://<host>/auth/apple/return`, a page that re-posts the same fields to `/auth/apple/callback` from our origin.
- **Connected accounts** on `/passkeys`: connect (POST `/auth/:provider` with `intent=connect` while signed in), disconnect (`IdentitiesController#destroy`, `Auth::DisconnectIdentityService`) unless it is the last way in. A passkey can now be removed when a connected account remains.
- **Pause**: `bin/rails platform:pause[oauth]`; `OmniauthPauseGate` (ahead of OmniAuth) sends the request phase to `/auth/failure?message=paused`.
- **Provider setup**: Google, an OAuth client with `https://<host>/auth/google_oauth2/callback`; Apple, a Services ID, a Sign in with Apple key and `https://<host>/auth/apple/return`; Microsoft, an app registration with `https://<host>/auth/microsoft_graph/callback`.
- **Not yet**: the native shells. Google refuses embedded web views, so the shells must open the system browser (ASWebAuthenticationSession, Custom Tabs) and come back through a one-use `AuthHandoff` token (`Auth::Handoffs.mint`, `Auth::RedeemHandoffService`); the route and the bridge are the next step. If the iOS app offers Google, App Review also expects Sign in with Apple there.

## Sign-ups

`SIGNUPS_ENABLED=0` closes account creation while sign-in stays open (`ensure_signups_open`, `signups_enabled?` in views).

## Specs

`spec/requests/passkey_flow_spec.rb` drives the whole flow with `WebAuthn::FakeClient` (origin `http://www.example.com`): register, use `/app`, sign out, sign in again, replay rejected, unknown credential rejected, passkey management. `spec/requests/native_only_spec.rb` covers the gate; `spec/controllers/api/v1/base_controller_spec.rb` the API header rule; `spec/requests/rack_attack_spec.rb` the throttle.

## Notes

- Synced passkeys (iCloud Keychain, Google Password Manager) report `sign_count` 0 forever; the gem accepts 0 to 0, so no false failures.
- `Sessions::PurgeStaleJob` (daily) deletes sessions unused for a year.
- `allow_browser versions: :modern` skips the native shells so an old Android System WebView is not answered with 406.
