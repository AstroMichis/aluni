package us.aluni

import android.app.Application
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.bridge.KotlinXJsonConverter
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.config.defaultFragmentDestination
import dev.hotwire.navigation.config.registerBridgeComponents
import dev.hotwire.navigation.config.registerFragmentDestinations
import dev.hotwire.navigation.config.registerRouteDecisionHandlers
import dev.hotwire.navigation.fragments.HotwireWebFragment
import us.aluni.bridge.NotificationTokenComponent
import us.aluni.bridge.PushPermissionComponent
import us.aluni.bridge.ShareComponent

class AluniApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        configureHotwire()
    }

    /** Bundled rules first, then the server's (GET /configurations/v1/android). */
    private fun loadPathConfiguration() {
        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                assetFilePath = "json/path_configuration.json",
                remoteFileUrl = "${BuildConfig.BASE_URL}/configurations/v1/android"
            )
        )
    }

    private fun configureHotwire() {
        // JSON serialization for bridge messages
        Hotwire.config.jsonConverter = KotlinXJsonConverter()

        // User agent prefix (the library appends "Hotwire Native Android; Turbo Native Android;",
        // which Rails reads as hotwire_native_app?).
        Hotwire.config.applicationUserAgentPrefix = "Aluni"

        Hotwire.config.debugLoggingEnabled = BuildConfig.DEBUG
        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG

        // Passkeys: every navigator's WebView comes from this factory, which turns on
        // the WebAuthn support of androidx.webkit (Android 14+ WebViews). Must be set
        // before the first Navigator is created.
        Hotwire.config.makeCustomWebView = { context -> AluniWebView(context) }

        // Default fragment for web content
        Hotwire.defaultFragmentDestination = HotwireWebFragment::class

        loadPathConfiguration()

        Hotwire.registerFragmentDestinations(
            HotwireWebFragment::class
        )

        // Names must match the Stimulus bridge controllers (app/javascript/controllers/bridge).
        Hotwire.registerBridgeComponents(
            BridgeComponentFactory("share", ::ShareComponent),
            BridgeComponentFactory("notification-token", ::NotificationTokenComponent),
            BridgeComponentFactory("push-permission", ::PushPermissionComponent)
        )

        Hotwire.registerRouteDecisionHandlers(
            dev.hotwire.navigation.routing.AppNavigationRouteDecisionHandler(),
            dev.hotwire.navigation.routing.BrowserTabRouteDecisionHandler(),
            dev.hotwire.navigation.routing.SystemNavigationRouteDecisionHandler()
        )
    }
}
