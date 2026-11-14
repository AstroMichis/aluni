package us.aluni

import android.os.Bundle
import com.google.android.material.bottomnavigation.BottomNavigationView
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import java.util.Locale

/**
 * One navigator per tab (Home, Account), each a NavigatorHost in activity_main.xml.
 * Rules come from the merged path configuration; tab titles from strings.xml.
 */
class MainActivity : HotwireActivity() {

    // Registered at creation (Android requires it before the activity starts);
    // the push-permission bridge asks through it.
    private var permissionCallback: ((Boolean) -> Unit)? = null
    private val notificationPermission =
        registerForActivityResult(androidx.activity.result.contract.ActivityResultContracts.RequestPermission()) { granted ->
            permissionCallback?.invoke(granted)
            permissionCallback = null
        }

    fun requestNotificationPermission(callback: (Boolean) -> Unit) {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.TIRAMISU) return callback(true)
        permissionCallback = callback
        notificationPermission.launch(android.Manifest.permission.POST_NOTIFICATIONS)
    }

    companion object {
        /** A tapped push carries the path to open. */
        const val EXTRA_PATH = "aluni.path"

        /** The app speaks English and Spanish; anything else falls back to English. */
        fun locale(): String = if (Locale.getDefault().language == "es") "es" else "en"
    }

    private val hostIds = listOf(R.id.navigator_home, R.id.navigator_account)
    private val tabItemIds = listOf(R.id.tab_home, R.id.tab_account)
    private val paths = listOf("/${locale()}/app", "/${locale()}/passkeys")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        intent?.getStringExtra(EXTRA_PATH)?.let { openPath(it) }
        setupBottomNavigation()
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra(EXTRA_PATH)?.let { openPath(it) }
    }

    override fun navigatorConfigurations(): List<NavigatorConfiguration> {
        val base = BuildConfig.BASE_URL.trimEnd('/')
        return paths.mapIndexed { index, path ->
            NavigatorConfiguration(
                name = if (index == 0) "home" else "account",
                startLocation = "$base$path",
                navigatorHostId = hostIds[index]
            )
        }
    }

    private fun openPath(path: String) {
        val base = BuildConfig.BASE_URL.trimEnd('/')
        window.decorView.post { delegate.currentNavigator?.route(if (path.startsWith("http")) path else "$base$path") }
    }

    private fun setupBottomNavigation() {
        val bottomNav = findViewById<BottomNavigationView>(R.id.bottom_navigation)
        bottomNav.setOnItemSelectedListener { item ->
            val index = tabItemIds.indexOf(item.itemId)
            if (index >= 0) showNavigator(hostIds[index]) else false
        }
    }

    private fun showNavigator(navigatorHostId: Int): Boolean {
        supportFragmentManager.beginTransaction().apply {
            hostIds.forEach { id ->
                supportFragmentManager.findFragmentById(id)?.let { fragment ->
                    if (id == navigatorHostId) show(fragment) else hide(fragment)
                }
            }
            commit()
        }
        return true
    }
}
