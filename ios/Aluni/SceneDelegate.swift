import UIKit
import HotwireNative

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var appNavigator: AppNavigator?
    private var openPathObserver: NSObjectProtocol?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        openPathObserver = NotificationCenter.default.addObserver(forName: .openPath, object: nil, queue: .main) { [weak self] note in
            guard let path = note.userInfo?["path"] as? String else { return }
            self?.appNavigator?.navigateToPath(path)
        }

        let navigator = AppNavigator()
        navigator.onSignInRequired = { [weak navigator] in
            navigator?.navigateToPath(ServerURL.signInPath)
        }
        appNavigator = navigator

        window.rootViewController = navigator.tabBarController
        window.makeKeyAndVisible()
        navigator.start()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if let observer = openPathObserver { NotificationCenter.default.removeObserver(observer) }
    }
}
