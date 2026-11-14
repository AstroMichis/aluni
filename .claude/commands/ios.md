# iOS Native Shell (Hotwire Native)

Build and maintain the iOS shell for Aluni with Hotwire Native (hotwire-native-ios 1.2). The shell lives at `/ios` in the Rails monorepo (XcodeGen spec `ios/project.yml`, sources under `ios/Aluni`). The request is: $ARGUMENTS

## Usage

```
/ios path-config                    # Update the bundled path_configuration.json and ConfigurationsController rules from routes
/ios bridge [component]             # Create a bridge component from an existing Stimulus bridge controller
/ios push-notifications             # APNs registration, token relay, Rails device token endpoint
/ios compliance                     # App Store Guideline 4.2 audit + Info.plist + privacy manifest check
/ios tab-bar                        # Change the native tabs (AppNavigator + native_app.yml)
/ios error-screen                   # The native offline/error screen
```

## Non-negotiable rules

- **Read the codebase first.** Routes come from `config/routes.rb`; never invent one. Every path rule maps to a real route; every bridge component maps to a real Stimulus controller in `app/javascript/controllers/bridge/`.
- **Never fabricate Swift APIs.** Use only what the verified reference below lists, or what already compiles in `ios/Aluni`. Ask before adding anything else.
- **Hotwire Native, not turbo-ios.** `import HotwireNative`, package `https://github.com/hotwired/hotwire-native-ios`, SPM only.
- **Passkeys only.** No biometric keychain token, no JWT exchange, no password form. WKWebView runs the WebAuthn ceremony on the Rails sign-in page; the shell only needs the `webcredentials:aluni.us` associated domain (Release entitlements) and the server's AASA `webcredentials` entry.
- **The server owns business values.** The shell draws chrome and routes; it never computes anything the server owns.
- **`mise exec --` is Rails-side only.** Xcode builds use `xcodegen generate` and `xcodebuild` directly. Full Xcode is not installed on the operator's machine today; generated code is reviewed, not compiled, here.
- **Monorepo.** The project stays at `/ios`; `Aluni.xcodeproj` is generated from `project.yml` and git-ignored.

## Folder structure

```
ios/
  project.yml                              # XcodeGen: target Aluni, bundle us.aluni.app, iOS 16, Swift 5.9, SPM HotwireNative, configFiles per configuration
  Aluni/
    AppDelegate.swift                      # HotwireConfig.setup(), UNUserNotificationCenter delegate, push token relay, tapped push -> .openPath
    SceneDelegate.swift                    # window, AppNavigator, .openPath observer, 401 -> sign-in
    Configuration/
      HotwireConfig.swift                  # UA prefix "Aluni", path configuration (bundle + server), web view, modals, bridge components, route handlers
      ServerURL.swift                      # BASE_URL from Info.plist, locale-prefixed start paths
      path_configuration.json              # bundled fallback (keep in sync with ConfigurationsController#rules)
    Config/Development.xcconfig, Production.xcconfig   # BASE_URL
    Navigation/AppNavigator.swift          # one Navigator per tab, lazy start, navigateToPath
    Navigation/NavigatorDelegateHandler.swift  # sign-out clears web data, 401 handling, native error screen
    Bridge/{Share,NotificationToken,PushPermission}Component.swift
    Screens/ErrorViewController.swift
    Supporting/Info.plist, PrivacyInfo.xcprivacy, Aluni.Release.entitlements, Assets.xcassets, en.lproj, es.lproj
```

`.gitignore` already covers `*.xcodeproj`, `xcuserdata`, `DerivedData`, `*.ipa`, `*.dSYM.zip`.

## Verified API reference

Use ONLY these (they compile in the reference shell and in `ios/Aluni`).

### Hotwire.config (set in HotwireConfig.swift before any Navigator exists)
| Property | Type | Notes |
|---|---|---|
| `applicationUserAgentPrefix` | String? | `"Aluni"`; the library appends `Hotwire Native iOS; Turbo Native iOS` |
| `showDoneButtonOnModals` | Bool | `true` |
| `backButtonDisplayMode` | enum | `.minimal` |
| `makeCustomWebView` | `(WKWebViewConfiguration) -> WKWebView` | `WKWebView(frame: .zero, configuration:)`, `allowsLinkPreview = false`; no WKProcessPool (deprecated, managed by the library) |
| `debugLoggingEnabled` | Bool | `#if DEBUG` |
| `pathConfiguration` | PathConfiguration | read settings after load |

Does not exist: `makeCustomErrorView` (use `NavigatorDelegate.visitableDidFailRequest` + `ErrorPresenter`), `configuration.preferences.isLinkPreviewEnabled`, shared `WKProcessPool`.

### Hotwire global methods
```swift
Hotwire.loadPathConfiguration(from: [.file(localURL), .server(remoteURL)])
Hotwire.registerBridgeComponents([ShareComponent.self, NotificationTokenComponent.self, PushPermissionComponent.self])  // ONE call; a second call replaces the first
Hotwire.registerRouteDecisionHandlers([AppNavigationRouteDecisionHandler(), SafariViewControllerRouteDecisionHandler(), SystemNavigationRouteDecisionHandler()])
```

### Navigator
```swift
let navigator = Navigator(configuration: Navigator.Configuration(name: String, startLocation: URL))
navigator.delegate = handler
navigator.rootViewController   // add as a tab or window root
navigator.start()
navigator.route(URL)           // also route(VisitProposal)
navigator.reload()
navigator.pop(); navigator.clearAll()
```

### NavigatorDelegate
```swift
typealias RetryBlock = () -> Void
func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult   // .accept | .acceptCustom(UIViewController) | .reject
func visitableDidFailRequest(_ visitable: Visitable, error: Error, retryHandler: RetryBlock?)
func didReceiveAuthenticationChallenge(_ challenge: URLAuthenticationChallenge, completionHandler: ...)
func formSubmissionDidStart(to url: URL); func formSubmissionDidFinish(at url: URL); func requestDidFinish(at url: URL)
```
`handle(proposal:from:)` needs the `from navigator:` parameter or it will not match the protocol. `proposal.url`, `proposal.viewController` (matches `PathConfigurationIdentifiable.pathConfigurationIdentifier`).

### BridgeComponent
```swift
final class ShareComponent: BridgeComponent {
    override class var name: String { "share" }                 // must equal the JS static component and the Kotlin factory name
    override func onReceive(message: Message) { ... }           // message.event, message.data<T>() (Decodable)
    // reply(to: "event") / reply(to: "event", with: Encodable)
    // delegate?.destination as? UIViewController to present from the hosting screen
}
```

### Swift 6 concurrency rule for every async callback
`requestAuthorization`, `NotificationCenter` observers and similar closures are not main-actor isolated. Always `DispatchQueue.main.async { [weak self] in self?.reply(...) }` (see `NotificationTokenComponent.swift`).

## Path configuration

Bundled file plus the server's rules, merged by the library:
```swift
Hotwire.loadPathConfiguration(from: [.file(localURL), .server(URL(string: "\(ServerURL.base)/configurations/v1/ios")!)])
```
The server side is `ConfigurationsController#rules` (`config/native_app.yml` for tabs and colours). Patterns are written for paths with or without the locale prefix: `(/(en|es))?/(sign_in|sign_up)$` → `presentation: replace`; `(/(en|es))?/sign_out$` → `clear_all`; `/new$`, `/edit$` → `context: modal`, `modal_style: large`; `(/(en|es))?/passkeys$` → no pull to refresh. A native screen is reached with `view_controller: "<identifier>"` on iOS (`uri: "hotwire://fragment/<name>"` on Android).

Properties: `context` (default | modal), `presentation` (default, push, pop, replace, replace_root, clear_all, refresh, none), `pull_to_refresh_enabled`, `animated`, `view_controller`, `modal_style` (large, medium, full, page_sheet, form_sheet), `modal_dismiss_gesture_enabled`.

## Authentication: passkeys in the web view

- Rails sessions are rows behind a permanent signed cookie; WKWebView keeps permanent cookies across launches, so nothing special is needed server side.
- The sign-in page runs `navigator.credentials.get()` inside WKWebView. That works only when the app's associated domains include `webcredentials:aluni.us` **and** `https://aluni.us/.well-known/apple-app-site-association` lists the app under `webcredentials` (`AppLinksController`, needs credentials `native_app.apple_team_id`). Both need the paid Apple team; the entitlements are Release-only so Debug builds sign with a free team.
- Sign-out: `NavigatorDelegateHandler` clears cookies and session storage when a `/sign_out` visit is proposed; the server's `clear_all` rule resets the stack.
- 401 from a visit (`visitableDidFailRequest`): `onSignInRequired` routes the current tab to `/<locale>/sign_in`.
- Development: `BASE_URL = http://localhost:3000` (secure context for WebAuthn; the simulator shares the Mac's localhost). A physical iPhone needs the Mac's LAN IP in `DEV_HOSTS` and will not run passkeys over plain http; use a tunnel with https for device testing of sign-in.

## Bridge components (three-part contract, same `name` in JS, Swift and Kotlin)

JS (`app/javascript/controllers/bridge/share_controller.js`): `static component = "share"`, `if (this.enabled) this.send("share", payload)` with a web fallback. Swift: `override class var name: String { "share" }`. Kotlin: `BridgeComponentFactory("share", ::ShareComponent)`. Register every Swift component in the one `Hotwire.registerBridgeComponents([...])` call in `HotwireConfig.swift`.

Existing: `share` (UIActivityViewController with text, URL and an optional downloaded image), `notification-token` (replies with the APNs token only when push is already authorized), `push-permission` (asks for push when the page asks, replies `{ granted, token, platform }`). Native-only elements are hidden on the web with `[data-bridge-components~="name"] [data-controller~="bridge--name"] { display: none !important; }` in `native.css` when needed.

## Rails integration points

`hotwire_native_app?` (turbo-rails) gates `NativeOnly` controllers and loads `native.css`; `recede_or_redirect_to`, `refresh_or_redirect_to`, `resume_or_redirect_to` after modal forms; `GET /configurations/v1/ios`; `GET /api/v1/me` with the session cookie (`X-Aluni-Native: 1` on writes); `POST /app/device_tokens` (`DELETE` with `token`) from the bridge components; `/.well-known/apple-app-site-association` (applinks + webcredentials).

## Tab bar

`AppNavigator` holds the tabs (home → `/<locale>/app`, account → `/<locale>/passkeys`), one `Navigator` each, started lazily when selected. SF Symbols for icons. The server's `settings.tabs` (titles, icons, URLs) mirrors them for a future remote-tabs build; keep `config/native_app.yml`, `AppNavigator.tabs` and `path_configuration.json` in sync when tabs change.

## Native screens

Only when a device API or App Store 4.2 requires it. `final class X: HotwireWebViewController, PathConfigurationIdentifiable { static var pathConfigurationIdentifier: String { "x" } }`, returned from `handle(proposal:from:)` as `.acceptCustom(...)`, mapped by `view_controller: "x"` in the rules.

## Push notifications (APNs)

`AppDelegate` relays the device token through `Notification.Name.didReceiveDeviceToken`; `PushPermissionComponent` asks for permission when the web page asks; `NotificationTokenComponent` re-registers when already authorized; the JS posts `{ token, platform: "ios" }` to `/app/device_tokens`. Rails: `action_push_native` with `.p8` token auth (`config/push.yml`, credentials `action_push_native.apns.*`, `topic` = `us.aluni.app`). A tapped push with `data.path` opens that path (`.openPath`). Entitlement `aps-environment production` in the Release entitlements; `UIBackgroundModes remote-notification` in Info.plist.

## App Store compliance (Guideline 4.2) checklist

Native value present: tab bar, push, Done button on modals, native error screen, Safari view controller for external links, the share sheet. Mandatory: `ITSAppUsesNonExemptEncryption = false`; usage descriptions only for APIs actually used (none today; add `NSCameraUsageDescription` the day an `<input type="file" capture>` exists); privacy manifest (`PrivacyInfo.xcprivacy`) matching the App Privacy answers; account deletion reachable in the app (Guideline 5.1.1v) once accounts hold data; privacy policy and terms URLs; App Review Notes naming the native features and a demo account (passkeys: provide a test device or a reviewer path); production backend live; screenshots for the 6.9-inch iPhone; 1024x1024 icon. Submit iOS first.

## Info.plist

Required bundle keys (`CFBundleIdentifier`, `CFBundleName`, `CFBundleDisplayName`, `CFBundleVersion`, `CFBundleShortVersionString`, `CFBundlePackageType`, `CFBundleExecutable`), `BASE_URL = $(BASE_URL)`, the scene manifest, `UILaunchScreen` with the `LaunchBackground` colour set (no storyboard), orientations, `UIBackgroundModes remote-notification`, and Debug-only `NSAppTransportSecurity.NSAllowsLocalNetworking` through `INFOPLIST_PREPROCESS` (`#ifdef DEBUG`).

## Secrets

Nothing secret lives in `/ios`. `BASE_URL` comes from the xcconfig files through `project.yml` `configFiles`. Signing uses automatic signing with the operator's team; CI signing, when it exists, injects certificates from encrypted secrets.

## Key conventions

Dark launch screen (`#0F2920`), minimal chrome, 48 pt touch targets on the web side, English primary with Spanish localisation (`en.lproj`, `es.lproj`), the web views inherit the Rails design tokens.
