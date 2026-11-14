import UIKit
import HotwireNative

/// Native error/offline screen shown when a web request fails (App Store
/// Guideline 4.2: never a browser error page).
final class ErrorViewController: UIViewController {

    private let error: Error
    private let retryHandler: NavigatorDelegate.RetryBlock?

    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("error.title", comment: "Offline title")
        label.font = .preferredFont(forTextStyle: .title2)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("error.message", comment: "Offline message")
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var retryButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = NSLocalizedString("error.retry", comment: "Retry button")
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        return button
    }()

    init(error: Error, retryHandler: NavigatorDelegate.RetryBlock?) {
        self.error = error
        self.retryHandler = retryHandler
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
    }

    // MARK: - Private

    private func setupLayout() {
        view.addSubview(stackView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)

        if retryHandler != nil {
            stackView.setCustomSpacing(24, after: messageLabel)
            stackView.addArrangedSubview(retryButton)
        }

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 280)
        ])
    }

    @objc private func retryTapped() {
        retryHandler?()
    }
}
