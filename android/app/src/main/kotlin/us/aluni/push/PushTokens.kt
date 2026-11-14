package us.aluni.push

/**
 * The FCM token, when Firebase is part of the build (google-services.json present,
 * see app/build.gradle.kts). Without Firebase the callback gets null.
 */
object PushTokens {
    fun current(callback: (String?) -> Unit) {
        runCatching {
            val messaging = Class.forName("com.google.firebase.messaging.FirebaseMessaging")
            val instance = messaging.getMethod("getInstance").invoke(null)
            @Suppress("UNCHECKED_CAST")
            val task = messaging.getMethod("getToken").invoke(instance) as com.google.android.gms.tasks.Task<String>
            task.addOnCompleteListener { callback(if (it.isSuccessful) it.result else null) }
        }.onFailure { callback(null) }
    }
}
