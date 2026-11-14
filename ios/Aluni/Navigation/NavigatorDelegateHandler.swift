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

    func visitableDidFailRequest(_ visitable: Visitable, error: Error, retryHandler: RetryBlock?) {
        let nsError = error as NSError
        if isUnauthorizedError(nsError) {
            DispatchQueue.main.async { [weak self] in self?.onSignInRequired?() }
            return
        }

        // A native error screen ("No connection" + "Try again"), never a blank web view.
        if let host = visitable as? UIViewController {
            let errorVC = ErrorViewController(error: error) { [weak host] in
                host?.children.filter { $0 is ErrorViewController }.forEach { $0.view.removeFromSuperview(); $0.removeFromParent() }
                retryHandler?()
            }
            host.addChild(errorVC)
            errorVC.view.frame = host.view.bounds
            errorVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            host.view.addSubview(errorVC.view)
            errorVC.didMove(toParent: host)
        } else if let errorPresenter = visitable as? ErrorPresenter {
            errorPresenter.presentError(error, retryHandler: retryHandler)
        }
    }

    // MARK: - Private

    private func clearWebData() {
        let dataTypes: Set<String> = [WKWebsiteDataTypeCookies, WKWebsiteDataTypeSessionStorage]
        WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: .distantPast) {}
    }

    private func isUnauthorizedError(_ error: NSError) -> Bool {
        if error.code == 401 { return true }
        if let statusCode = error.userInfo["statusCode"] as? Int, statusCode == 401 { return true }
        return false
    }
}
