import HotwireNative
import UIKit

/// `share`: the native share sheet with the text, an optional link and an image
/// (downloaded first). Mirrors app/javascript/controllers/bridge/share_controller.js.
final class ShareComponent: BridgeComponent {
    override class var name: String { "share" }

    override func onReceive(message: Message) {
        guard message.event == "share", let data: ShareData = message.data() else { return }
        var items: [Any] = [ data.text ]
        if let link = data.url, let url = URL(string: link), !link.isEmpty { items.append(url) }

        let present: ([Any]) -> Void = { [weak self] items in
            guard let host = self?.delegate?.destination as? UIViewController else { return }
            let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
            sheet.popoverPresentationController?.sourceView = host.view
            host.present(sheet, animated: true)
        }

        guard let imageLink = data.imageUrl, let imageURL = URL(string: imageLink), !imageLink.isEmpty else {
            return present(items)
        }
        URLSession.shared.dataTask(with: imageURL) { body, _, _ in
            DispatchQueue.main.async {
                if let body, let image = UIImage(data: body) { present(items + [ image ]) } else { present(items) }
            }
        }.resume()
    }
}

private struct ShareData: Decodable {
    let text: String
    let url: String?
    let imageUrl: String?
}
