# Android Native Shell (Hotwire Native)

Build and maintain the Android shell for Aluni with Hotwire Native (hotwire-native-android 1.2). The shell lives at `/android` in the Rails monorepo (Gradle KTS, Kotlin, package `us.aluni`, applicationId `us.aluni.app`). The request is: $ARGUMENTS

## Usage

```
/android path-config                # Update assets/json/path_configuration.json and ConfigurationsController rules from routes
/android bridge [component]         # Create a bridge component from an existing Stimulus bridge controller
/android push-notifications         # FCM registration, token relay, Rails device token endpoint
/android compliance                 # Google Play WebView policy audit + manifest check
/android tab-bar                    # Change the bottom navigation (MainActivity + native_app.yml)
/android error-screen               # Native offline/error handling
```

## Non-negotiable rules

- **Read the codebase first.** Routes come from `config/routes.rb`; never invent one. Every path rule maps to a real route; every bridge component maps to a real Stimulus controller in `app/javascript/controllers/bridge/`.
- **Never fabricate Kotlin APIs.** Use only what the verified reference below lists, or what already exists in `android/app/src/main/kotlin/us/aluni`. Ask before adding anything else.
- **Hotwire Native, not turbo-android.** Artifacts `dev.hotwire:core` and `dev.hotwire:navigation-fragments`.
- **Passkeys only.** No password form, no token exchange. The system WebView runs the WebAuthn ceremony on the Rails sign-in page once `AluniWebView` turns on WebAuthn support (androidx.webkit) and `aluni.us/.well-known/assetlinks.json` lists this app with `delegate_permission/common.get_login_creds`. Android 14+ WebViews only; older devices see the page's "unsupported" message until a native Credential Manager bridge exists.
- **AAB only, target API 35, minSdk 28, Java 17.** Same `name` string for every bridge component across JS, Swift and Kotlin.
- **`mise exec --` is Rails-side only.** Android builds use `./gradlew`. JDK 17 and the Android SDK are not installed on the operator's machine today; generated code is reviewed, not compiled, here.
- **Monorepo.** The project stays at `/android`.

## Folder structure

```
android/
  settings.gradle.kts, build.gradle.kts, gradle.properties (android.useAndroidX=true)
  gradle/libs.versions.toml                # AGP 8.13.2, Kotlin 2.0.21, hotwire 1.2.0, androidx-webkit 1.13.0, material, firebase-messaging
  gradle/wrapper/, gradlew, gradlew.bat
  app/build.gradle.kts                     # namespace us.aluni, applicationId us.aluni.app, BASE_URL per build type, minify in release
  app/proguard-rules.pro
  app/src/main/AndroidManifest.xml         # INTERNET, POST_NOTIFICATIONS, autoVerify app links for aluni.us, FCM service
  app/src/main/kotlin/us/aluni/
    AluniApplication.kt                    # Hotwire.config, makeCustomWebView, path configuration, bridge components, route handlers
    AluniWebView.kt                        # HotwireWebView subclass with WebAuthn support on
    MainActivity.kt                        # HotwireActivity: two NavigatorHosts + BottomNavigationView, push tap -> route
    bridge/{Share,NotificationToken,PushPermission}Component.kt
    push/{AluniMessagingService,PushTokens}.kt
  app/src/main/assets/json/path_configuration.json   # bundled fallback (assets/, NOT res/raw/)
  app/src/main/res/{layout,menu,drawable,color,values,values-es,mipmap-anydpi-v26}
```

`.gitignore` covers `.gradle/`, `build/`, `local.properties`, `*.iml`, `.idea/`, `app/google-services.json`.

## Verified API reference

Use ONLY these (they compile in the reference shell and in `android/`).

### Imports that are extension functions (required, or nothing compiles)
```kotlin
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.bridge.KotlinXJsonConverter
import dev.hotwire.core.turbo.config.PathConfiguration          // NOT dev.hotwire.core.config.PathConfiguration
import dev.hotwire.core.turbo.webview.HotwireWebView
import dev.hotwire.navigation.config.defaultFragmentDestination
import dev.hotwire.navigation.config.registerBridgeComponents
import dev.hotwire.navigation.config.registerFragmentDestinations
import dev.hotwire.navigation.config.registerRouteDecisionHandlers
import dev.hotwire.navigation.fragments.HotwireWebFragment
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
```

### Hotwire.config (Application.onCreate, before any Navigator)
| Property | Notes |
|---|---|
| `jsonConverter = KotlinXJsonConverter()` | required for bridge messages |
| `applicationUserAgentPrefix = "Aluni"` | the library appends `Hotwire Native Android; Turbo Native Android` |
| `debugLoggingEnabled`, `webViewDebuggingEnabled` | `BuildConfig.DEBUG` |
| `makeCustomWebView = { context -> AluniWebView(context) }` | `(Context) -> HotwireWebView`; every Navigator's WebView comes from here, also after a render-process death |
| `Hotwire.defaultFragmentDestination = HotwireWebFragment::class` | |

```kotlin
Hotwire.loadPathConfiguration(context = this, location = PathConfiguration.Location(
    assetFilePath = "json/path_configuration.json",                 // AssetManager path, relative to assets/
    remoteFileUrl = "${BuildConfig.BASE_URL}/configurations/v1/android"))
Hotwire.registerFragmentDestinations(HotwireWebFragment::class)
Hotwire.registerBridgeComponents(BridgeComponentFactory("share", ::ShareComponent), ...)
Hotwire.registerRouteDecisionHandlers(
    dev.hotwire.navigation.routing.AppNavigationRouteDecisionHandler(),   // no context parameter
    dev.hotwire.navigation.routing.BrowserTabRouteDecisionHandler(),
    dev.hotwire.navigation.routing.SystemNavigationRouteDecisionHandler())
```

### HotwireWebView
`open class HotwireWebView(context: Context, attrs: AttributeSet? = null) : WebView` whose `init` applies the library's settings. `AluniWebView` subclasses it and, when `WebViewFeature.isFeatureSupported(WebViewFeature.WEB_AUTHENTICATION)`, calls `WebSettingsCompat.setWebAuthenticationSupport(settings, WebSettingsCompat.WEB_AUTHENTICATION_SUPPORT_FOR_APP)` (androidx.webkit, UI thread).

### HotwireActivity / NavigatorConfiguration
```kotlin
class MainActivity : HotwireActivity() {
    override fun navigatorConfigurations() = listOf(
        NavigatorConfiguration(name = "home", startLocation = "$base/en/app", navigatorHostId = R.id.navigator_home),
        NavigatorConfiguration(name = "account", startLocation = "$base/en/passkeys", navigatorHostId = R.id.navigator_account))
}
// delegate.currentNavigator?.route(url)  to open a path (push tap)
```
Layout: one `androidx.fragment.app.FragmentContainerView` with `android:name="dev.hotwire.navigation.navigator.NavigatorHost"` per tab, plus a `BottomNavigationView`; show/hide the hosts on tab selection.

### BridgeComponent<HotwireDestination>
```kotlin
class ShareComponent(name: String, delegate: BridgeDelegate<HotwireDestination>) : BridgeComponent<HotwireDestination>(name, delegate) {
    override fun onReceive(message: Message) { if (message.event != "share") return; val data = message.data<ShareData>() ?: return; ... }
    @Serializable data class ShareData(val text: String, val url: String? = null)
}
// replyTo("event") / replyTo("event", serializableData); delegate.destination.fragment for context, activity, startActivity
```

### Native fragments
`@HotwireDestinationDeepLink(uri = "hotwire://fragment/<name>") class XFragment : HotwireWebFragment()`, registered in `registerFragmentDestinations`, mapped by `uri` in the path rules (Android uses `uri`, iOS `view_controller`).

## Path configuration

Bundled `assets/json/path_configuration.json` plus the server's `/configurations/v1/android` (`ConfigurationsController#rules`, tabs and colours from `config/native_app.yml`). Patterns cover paths with or without the locale prefix: `(/(en|es))?/(sign_in|sign_up)$` → `presentation: replace`; `(/(en|es))?/sign_out$` → `clear_all`; `/new$`, `/edit$` → `context: modal`; `(/(en|es))?/passkeys$` → no pull to refresh. Android defaults `pull_to_refresh_enabled` to false; set it explicitly where wanted. Properties: `context`, `presentation`, `pull_to_refresh_enabled`, `animated`, `uri`, `fallback_uri`, `title`.

## Authentication: passkeys in the WebView

- Rails sessions are rows behind a permanent signed cookie; the WebView's `CookieManager` keeps permanent cookies across restarts.
- The sign-in page runs `navigator.credentials.get()` inside the WebView. Requirements: `AluniWebView` (WebAuthn support on), the Digital Asset Links file at `https://aluni.us/.well-known/assetlinks.json` with relations `delegate_permission/common.handle_all_urls` and `delegate_permission/common.get_login_creds` for `us.aluni.app` and the release signing certificate fingerprint (`AppLinksController`, credentials `native_app.android_cert_sha256`), and an Android 14+ system WebView. Verify on a device; the emulator needs Play services.
- Sign-out: the `clear_all` rule resets the stack; clear cookies (`CookieManager.getInstance().removeAllCookies(null); flush()`) if a native sign-out control appears.
- Development: `BASE_URL = http://localhost:3000` in debug with `usesCleartextTraffic` true; run `adb reverse tcp:3000 tcp:3000` so the device's localhost reaches the Mac (localhost, not `10.0.2.2`, because WebAuthn needs a secure context). Rails runs with `bin/rails server -b 0.0.0.0`.

## Bridge components (three-part contract, same `name` in JS, Swift and Kotlin)

JS (`app/javascript/controllers/bridge/*_controller.js`) sends when `this.enabled`; Kotlin class registered through `BridgeComponentFactory("name", ::Component)` in `AluniApplication`. Existing: `share` (ACTION_SEND chooser), `notification-token` (replies with the FCM token when notifications are enabled), `push-permission` (asks `POST_NOTIFICATIONS` on Android 13+ through `MainActivity.requestNotificationPermission`, replies `{ granted, token, platform: "android" }`).

## Rails integration points

Same as iOS: `hotwire_native_app?`, `recede_or_redirect_to` and friends, `/configurations/v1/android`, `/api/v1/me` (`X-Aluni-Native: 1` on writes), `POST /app/device_tokens`, `/.well-known/assetlinks.json`. User agent: `"Aluni Hotwire Native Android; Turbo Native Android; bridge-components: ..."`.

## Push notifications (FCM)

`AluniMessagingService` receives data messages from the Rails push channel (`title`, `body`, `data.path`, `data.group`), posts them on one channel grouped by `group`, and a tap opens `MainActivity` with `EXTRA_PATH`. `PushTokens.current` reads the FCM token reflectively so the app compiles without Firebase; the Google services plugin applies only when `app/google-services.json` exists (git-ignored; from a free Firebase project). Rails: `action_push_native` with credentials `action_push_native.fcm.*`; the channel clears `collapse_key` and sends the group in `data.group`.

## Google Play compliance checklist

Native value: bottom navigation, FCM push, bridge components, native error handling, Chrome Custom Tabs for external links, system handler for `tel:`/`mailto:`. Mandatory: never call `SslErrorHandler.proceed()` (the library's clients handle SSL; always `cancel()` on error); target API 35, minSdk 28; `INTERNET` permission; AAB (`./gradlew bundleRelease`); Data Safety form; privacy policy URL; account deletion in the app and on the web once accounts hold data; IARC rating; `usesCleartextTraffic` false in release (the manifest placeholder does this); 512x512 icon and 1024x500 feature graphic; two screenshots per device type. Verified app links need the release certificate fingerprint in `assetlinks.json`.

## Secrets and signing

Nothing secret lives in `/android`. `BASE_URL` is a `buildConfigField` per build type. Keystores are never committed; CI decodes a base64 secret into a file for `signingConfigs` when a release pipeline exists.

## Pitfalls

- XML comments cannot contain `--` (so never paste a CSS custom property name into a resource comment).
- `assetFilePath` is relative to `src/main/assets/`, never `res/raw/`.
- `gradle.properties` must contain `android.useAndroidX=true`.
- The adaptive launcher icon is `mipmap-anydpi-v26/ic_launcher.xml` (vector foreground + colour background); density PNGs are not needed for API 26+, which is everything above minSdk 28.
- Register all bridge components in one `registerBridgeComponents` call.

## Key conventions

Dark theme (`Theme.Aluni`, tokens from `base/variables.css`), `MODE_NIGHT_FOLLOW_SYSTEM` behaviour through `DayNight`, 48 dp touch targets, English primary with `values-es` Spanish, minimal Material chrome; the web views inherit the Rails design.
