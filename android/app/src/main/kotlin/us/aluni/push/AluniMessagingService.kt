package us.aluni.push

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import us.aluni.MainActivity
import us.aluni.R

/**
 * Receives FCM messages from the Rails push channel (title, body, data.path,
 * data.group) and posts them; tapping one opens its path in the app.
 */
class AluniMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        post(
            this,
            title = message.notification?.title ?: data["title"],
            body = message.notification?.body ?: data["body"],
            group = data["group"],
            path = data["path"]
        )
    }

    companion object {
        private const val CHANNEL_ID = "aluni.default"

        fun post(context: Context, title: String?, body: String?, group: String?, path: String?) {
            val manager = NotificationManagerCompat.from(context)
            if (!manager.areNotificationsEnabled()) return

            val systemManager = context.getSystemService(NotificationManager::class.java)
            systemManager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, context.getString(R.string.notification_channel), NotificationManager.IMPORTANCE_DEFAULT)
            )

            val open = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(MainActivity.EXTRA_PATH, path ?: "/")
            }
            val pending = PendingIntent.getActivity(
                context, (path ?: "/").hashCode(), open,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setGroup(group)
                .setContentIntent(pending)
                .setAutoCancel(true)
                .build()

            manager.notify(System.currentTimeMillis().toInt(), notification)
        }
    }
}
