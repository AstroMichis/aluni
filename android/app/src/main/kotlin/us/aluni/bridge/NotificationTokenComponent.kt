package us.aluni.bridge

import androidx.core.app.NotificationManagerCompat
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable
import us.aluni.push.PushTokens

/**
 * `notification-token`: relays the FCM token to the web page once notifications
 * are already allowed. Never asks for permission itself; `push-permission` does.
 * Without Firebase (no google-services.json) there is no token and nothing is sent.
 */
class NotificationTokenComponent(name: String, delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "connect") return
        val context = delegate.destination.fragment.requireContext()
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return
        PushTokens.current { token ->
            if (token != null) replyTo("connect", TokenData(token = token))
        }
    }

    @Serializable data class TokenData(val token: String, val platform: String = "android")
}
