package us.aluni.bridge

import android.content.Intent
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable

/** `share`: the Android share sheet with the text and link. */
class ShareComponent(name: String, delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "share") return
        val data = message.data<ShareData>() ?: return
        val text = listOfNotNull(data.text, data.url?.takeIf { it.isNotBlank() }).joinToString(" ")
        val intent = Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, text) }
        delegate.destination.fragment.startActivity(Intent.createChooser(intent, null))
    }

    @Serializable data class ShareData(val text: String, val url: String? = null, val imageUrl: String? = null)
}
