import HotwireNative
import UIKit
import UserNotifications

/// `push-permission`: asks for push only when the web page asks, then replies
/// with { granted, token, platform }.
final class PushPermissionComponent: BridgeComponent {
    override class var name: String { "push-permission" }

    private var tokenObserver: NSObjectProtocol?

    deinit {
        if let tokenObserver { NotificationCenter.default.removeObserver(tokenObserver) }
    }

    override func onReceive(message: Message) {
        guard message.event == "request" else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard granted else { return self.reply(to: "request", with: PermissionReply(granted: false, token: nil, platform: "ios")) }
                self.tokenObserver = NotificationCenter.default.addObserver(forName: .didReceiveDeviceToken, object: nil, queue: .main) { [weak self] note in
                    let token = note.userInfo?["token"] as? String
                    self?.reply(to: "request", with: PermissionReply(granted: true, token: token, platform: "ios"))
                }
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}

private struct PermissionReply: Encodable {
    let granted: Bool
    let token: String?
    let platform: String
}
