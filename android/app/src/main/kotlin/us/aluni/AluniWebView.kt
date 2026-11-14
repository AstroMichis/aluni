package us.aluni

import android.content.Context
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import dev.hotwire.core.turbo.webview.HotwireWebView

/**
 * The web view every navigator uses (Hotwire.config.makeCustomWebView). Turns on
 * the WebAuthn support of androidx.webkit so the Rails sign-in page can create
 * and use passkeys for aluni.us inside the app. The system WebView grants it only
 * on Android 14+ and only when aluni.us publishes this app in assetlinks.json
 * with the get_login_creds relation (AppLinksController). On older WebViews the
 * feature is simply absent and the page shows its "unsupported" message.
 */
class AluniWebView(context: Context) : HotwireWebView(context, null) {
    init {
        if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_AUTHENTICATION)) {
            WebSettingsCompat.setWebAuthenticationSupport(
                settings,
                WebSettingsCompat.WEB_AUTHENTICATION_SUPPORT_FOR_APP
            )
        }
    }
}
