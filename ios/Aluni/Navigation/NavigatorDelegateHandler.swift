import UIKit
import HotwireNative
import WebKit

final class NavigatorDelegateHandler: NavigatorDelegate {

    static let shared = NavigatorDelegateHandler()
    private init() {}

    /// Called when a request answers 401: the session cookie is gone.
    var onSignInRequired: (() -> Void)?

    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
        if proposal.url.path.contains("/sign_out") {
            clearWebData()
        }
        return .accept
    }

    /// hotwire-native-ios 1.3 hands over a typed `HotwireNativeError`; for an
    /// HTTP failure `statusCode` carries the status, otherwise it is nil.
    func visitableDidFailRequest(_ visitable: Visitable, error: HotwireNativeError, retryHandler: RetryBlock?) {
        if error.statusCode == 401 {
            DispatchQueue.main.async { [weak self] in self?.onSignInRequired?() }
            return
        }

        // A native error screen ("No connection" + "Try again"), never a blank web view.
        let host = visitable.visitableViewController
        let errorVC = ErrorViewController(error: error) { [weak host] in
            host?.children.filter { $0 is ErrorViewController }.forEach { $0.view.removeFromSuperview(); $0.removeFromParent() }
            retryHandler?()
        }
        host.addChild(errorVC)
        errorVC.view.frame = host.view.bounds
        errorVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.addSubview(errorVC.view)
        errorVC.didMove(toParent: host)
    }

    // MARK: - Private

    private func clearWebData() {
        let dataTypes: Set<String> = [WKWebsiteDataTypeCookies, WKWebsiteDataTypeSessionStorage]
        WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: .distantPast) {}
    }
}
