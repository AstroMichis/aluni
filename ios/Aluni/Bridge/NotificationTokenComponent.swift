import HotwireNative
import UIKit
import UserNotifications

/// `notification-token`: relays the APNs device token to the web page once push
/// is already authorized. Never asks for permission itself; `push-permission` does.
final class NotificationTokenComponent: BridgeComponent {

    override class var name: String { "notification-token" }

    private var tokenObserver: NSObjectProtocol?

    override func onReceive(message: Message) {
        guard message.event == "connect" else { return }
        registerIfAuthorized()
    }

    deinit {
        if let observer = tokenObserver { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: - Private

    private func registerIfAuthorized() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

            DispatchQueue.main.async { [weak self] in
                self?.tokenObserver = NotificationCenter.default.addObserver(forName: .didReceiveDeviceToken, object: nil, queue: .main) { notification in
                    guard let token = notification.userInfo?["token"] as? String else { return }
                    DispatchQueue.main.async { [weak self] in
                        self?.reply(to: "connect", with: TokenData(token: token, platform: "ios"))
                    }
                }
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}

private struct TokenData: Encodable {
    let token: String
    let platform: String
}
