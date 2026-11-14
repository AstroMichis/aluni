import UIKit
import HotwireNative
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        HotwireConfig.setup()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - UISceneSession

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    // MARK: - Push notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NotificationCenter.default.post(name: .didReceiveDeviceToken, object: nil, userInfo: ["token": token])
    }
}

// MARK: - Push presentation and taps

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Show pushes while the app is open; iOS stacks them by aps.thread-id.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    /// A tapped push opens its `path` (data.path from the Rails push channel).
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let path = response.notification.request.content.userInfo["path"] as? String {
            NotificationCenter.default.post(name: .openPath, object: nil, userInfo: ["path": path])
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let didReceiveDeviceToken = Notification.Name("didReceiveDeviceToken")
    static let openPath = Notification.Name("openPath")
}
