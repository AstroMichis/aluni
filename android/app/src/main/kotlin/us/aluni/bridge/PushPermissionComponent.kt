package us.aluni.bridge

import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable
import us.aluni.MainActivity
import us.aluni.push.PushTokens

/**
 * `push-permission`: asks only when the page asks. Android 13+ needs
 * POST_NOTIFICATIONS; then replies with the FCM token when Firebase is
 * configured (google-services.json), granted=true otherwise.
 */
class PushPermissionComponent(name: String, delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "request") return
        val activity = delegate.destination.fragment.activity as? MainActivity ?: return
        activity.requestNotificationPermission { granted -> answer(granted) }
    }

    private fun answer(granted: Boolean) {
        if (!granted) return replyTo("request", Reply(granted = false))
        PushTokens.current { token -> replyTo("request", Reply(granted = true, token = token)) }
    }

    @Serializable data class Reply(val granted: Boolean, val token: String? = null, val platform: String = "android")
}
