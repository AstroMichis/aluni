# Native shells (Hotwire Native)

One app, one bundle id (`us.aluni.app`), two shells around this Rails app: `ios/` (Swift, XcodeGen) and `android/` (Kotlin, Gradle KTS). The shells draw navigation chrome; every screen is a Rails page. Neither shell computes a business value the server owns.

## Server side

| Piece | Role |
|---|---|
| `config/native_app.yml` + `app/services/native_app.rb` | App name, bundle id, UA prefix, sign-in/home paths, app-link paths, colours, tabs |
| `GET /configurations/v1/:platform` (`ConfigurationsController`) | Tabs with per-platform icons, colours and the path rules the shells merge over their bundled `path_configuration.json` (declared first in routes) |
| `GET /.well-known/apple-app-site-association`, `/.well-known/assetlinks.json` (`AppLinksController`) | Universal/app links **and** the passkey associations (`webcredentials`, `get_login_creds`). 404 until credentials `native_app.apple_team_id` / `native_app.android_cert_sha256` exist |
| `hotwire_native_app?` (turbo-rails) | Layouts load `native.css` (hides web chrome) and mount bridge components; `NativeOnly` gates the app pages |
| `Api::V1::BaseController` | JSON for native screens: session cookie + `X-Aluni-Native: 1` on writes |
| `app/javascript/controllers/bridge/*` | `share`, `notification-token`, `push-permission`; names match the Swift and Kotlin components exactly |

## iOS (`ios/`)

`project.yml` (XcodeGen; `xcodegen generate` recreates the git-ignored `Aluni.xcodeproj`): iOS 16, Swift 5.9, SPM `hotwire-native-ios` 1.2, `Config/{Development,Production}.xcconfig` carry `BASE_URL`. Sources: `AppDelegate` (push token, tapped push opens its path), `SceneDelegate`, `Configuration/HotwireConfig.swift` (UA prefix `Aluni`, bundled + server path configuration, bridge components, route decision handlers), `Configuration/ServerURL.swift`, `Navigation/AppNavigator.swift` (one Navigator per tab, lazy start) and `NavigatorDelegateHandler.swift` (sign-out clears web data, 401 routes to sign-in, native error screen), `Bridge/*Component.swift`, `Screens/ErrorViewController.swift`, `Supporting/` (Info.plist with Debug-only local networking, `PrivacyInfo.xcprivacy`, Release-only `Aluni.Release.entitlements` with `applinks:aluni.us`, `webcredentials:aluni.us`, `aps-environment`).

## Android (`android/`)

Gradle KTS with a version catalog (AGP 8.13.2, Kotlin 2.0.21, Hotwire 1.2.0, androidx.webkit 1.13.0, Java 17), compile/target SDK 35, minSdk 28, AAB with minify in release. `AluniApplication` configures Hotwire (UA prefix, `makeCustomWebView = { AluniWebView(it) }`, bundled + server path configuration, bridge components, route decision handlers); `MainActivity` is a `HotwireActivity` with two `NavigatorHost`s (home, account) and a bottom navigation; `AluniWebView` turns on the WebView WebAuthn support; `push/` holds the FCM service (grouped notifications, tap opens the path) and `PushTokens`. Debug `BASE_URL` is `http://localhost:3000` with cleartext allowed; run `adb reverse tcp:3000 tcp:3000`. FCM compiles without Firebase; drop `app/google-services.json` in to enable it (git-ignored).

## Passkeys in the web views

Both shells sign in through the same Rails pages. iOS needs the `webcredentials` associated domain (paid Apple team) and the AASA `webcredentials` entry; Android needs `AluniWebView` plus the `get_login_creds` relation in `assetlinks.json` and an Android 14+ WebView. Older Android devices get the page's "unsupported" message. The upgrade path, when needed: a `passkey` bridge component that calls `ASAuthorizationController` / Credential Manager natively and posts the same JSON to the same Rails endpoints; `config/initializers/webauthn.rb` then adds the Android `android:apk-key-hash:` origin to `allowed_origins`.

## Building

Not possible on this machine (XcodeGen is installed, full Xcode and Java are not). Requirements: Xcode 16 for `ios/` (`cd ios && xcodegen generate && open Aluni.xcodeproj`), JDK 17 and Android Studio or the command-line SDK for `android/` (`./gradlew assembleDebug`). The Rails server for a simulator: `mise exec -- bin/rails server -b 0.0.0.0 -p 3000`; the iOS simulator reaches `localhost` directly, the Android emulator through `adb reverse`.

## Store notes

App Store Guideline 4.2: the shells have native navigation, a native error screen and the share sheet; keep adding native value as screens appear. Google Play: verified app links need the release signing certificate fingerprint in `assetlinks.json`. Apple's CDN caches the AASA; changes propagate slowly.
