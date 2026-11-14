import UIKit
import HotwireNative

/// One Navigator per tab, started lazily. Tabs are static here (the server's
/// /configurations/v1/ios also lists them under settings.tabs for a future
/// remote-tabs build); rules come from the merged path configuration.
final class AppNavigator: NSObject {

    let tabBarController = UITabBarController()

    /// Called when a Navigator receives a 401: the session is gone, show sign-in.
    var onSignInRequired: (() -> Void)?

    private var navigators: [Navigator] = []
    private var startedTabs: Set<Int> = []

    struct Tab {
        let key: String
        let title: String
        let path: String
        let systemImage: String
    }

    private let tabs: [Tab] = [
        Tab(key: "home", title: NSLocalizedString("tab.home", comment: "Home tab"), path: ServerURL.homePath, systemImage: "house"),
        Tab(key: "account", title: NSLocalizedString("tab.account", comment: "Account tab"), path: ServerURL.accountPath, systemImage: "person.crop.circle")
    ]

    override init() {
        super.init()
        configureTabBar()
        configureNavigators()
        tabBarController.delegate = self
    }

    /// Starts only the first (selected) tab's Navigator; other tabs load when tapped.
    func start() {
        startNavigatorIfNeeded(at: 0)
    }

    func reloadCurrentTab() {
        let index = tabBarController.selectedIndex
        guard index < navigators.count else { return }
        navigators[index].reload()
    }

    /// Opens a path (a tapped push, a link) in the tab it belongs to.
    func navigateToPath(_ path: String) {
        let tabIndex = tabIndexForPath(path)
        tabBarController.selectedIndex = tabIndex
        startNavigatorIfNeeded(at: tabIndex)
        guard let url = URL(string: path.hasPrefix("http") ? path : "\(ServerURL.base)\(path)") else { return }
        navigators[tabIndex].route(url)
    }

    // MARK: - Private

    private func tabIndexForPath(_ path: String) -> Int {
        if let exact = tabs.firstIndex(where: { path == $0.path }) { return exact }
        return tabs.dropFirst().firstIndex(where: { path.hasPrefix($0.path) }) ?? 0
    }

    private func startNavigatorIfNeeded(at index: Int) {
        guard !startedTabs.contains(index), index < navigators.count else { return }
        startedTabs.insert(index)
        navigators[index].start()
    }

    private func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "TabBarBackground") ?? UIColor.systemBackground
        tabBarController.tabBar.tintColor = UIColor(red: 0x5B / 255, green: 0x8D / 255, blue: 0xEF / 255, alpha: 1)
        tabBarController.tabBar.standardAppearance = appearance
        tabBarController.tabBar.scrollEdgeAppearance = appearance
    }

    private func configureNavigators() {
        let delegateHandler = NavigatorDelegateHandler.shared
        delegateHandler.onSignInRequired = { [weak self] in self?.onSignInRequired?() }

        let viewControllers: [UIViewController] = tabs.enumerated().compactMap { index, tab in
            guard let url = URL(string: "\(ServerURL.base)\(tab.path)") else { return nil }
            let configuration = Navigator.Configuration(name: tab.title, startLocation: url)
            let navigator = Navigator(configuration: configuration)
            navigator.delegate = delegateHandler
            navigators.append(navigator)

            let rootVC = navigator.rootViewController
            rootVC.tabBarItem = UITabBarItem(title: tab.title, image: UIImage(systemName: tab.systemImage), tag: index)
            return rootVC
        }

        tabBarController.viewControllers = viewControllers
    }
}

// MARK: - UITabBarControllerDelegate

extension AppNavigator: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard let index = tabBarController.viewControllers?.firstIndex(of: viewController) else { return }
        startNavigatorIfNeeded(at: index)
    }
}
