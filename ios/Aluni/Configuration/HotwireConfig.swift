import Foundation
import HotwireNative
import WebKit

enum HotwireConfig {

    static func setup() {
        #if DEBUG
        Hotwire.config.debugLoggingEnabled = true
        #else
        assert(ServerURL.base.hasPrefix("https://"), "Production must use HTTPS")
        #endif
        configureUserAgent()
        loadPathConfiguration()
        configureWebView()
        configureModals()
        registerBridgeComponents()
        registerRouteDecisionHandlers()
    }

    // MARK: - Private

    /// The library appends "Hotwire Native iOS; Turbo Native iOS", which Rails
    /// reads as hotwire_native_app? (the native gate and native.css).
    private static func configureUserAgent() {
        Hotwire.config.applicationUserAgentPrefix = "Aluni"
    }

    /// Bundled rules first, then the server's (GET /configurations/v1/ios).
    static func loadPathConfiguration() {
        guard let localURL = Bundle.main.url(forResource: "path_configuration", withExtension: "json") else {
            assertionFailure("Missing path_configuration.json in bundle")
            return
        }
        guard let remoteURL = URL(string: "\(ServerURL.base)/configurations/v1/ios") else {
            assertionFailure("Invalid server URL for path configuration")
            return
        }

        Hotwire.loadPathConfiguration(from: [
            .file(localURL),
            .server(remoteURL)
        ])
    }

    /// Passkeys: WKWebView runs the WebAuthn ceremony itself once the app's
    /// associated domains include webcredentials:aluni.us (Release entitlements);
    /// no Swift code is involved.
    private static func configureWebView() {
        Hotwire.config.makeCustomWebView = { configuration in
            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.allowsLinkPreview = false
            #if DEBUG
            // Safari on the Mac (Develop menu > the device > Aluni) can then
            // inspect the page and show the real WebAuthn error.
            if #available(iOS 16.4, *) { webView.isInspectable = true }
            #endif
            return webView
        }
    }

    private static func configureModals() {
        Hotwire.config.showDoneButtonOnModals = true
        Hotwire.config.backButtonDisplayMode = .minimal
    }

    /// Names must match the Stimulus bridge controllers (app/javascript/controllers/bridge).
    private static func registerBridgeComponents() {
        Hotwire.registerBridgeComponents([
            ShareComponent.self,
            NotificationTokenComponent.self,
            PushPermissionComponent.self
        ])
    }

    private static func registerRouteDecisionHandlers() {
        Hotwire.registerRouteDecisionHandlers([
            AppNavigationRouteDecisionHandler(),
            SafariViewControllerRouteDecisionHandler(),
            SystemNavigationRouteDecisionHandler()
        ])
    }
}
