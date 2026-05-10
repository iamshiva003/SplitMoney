import UIKit
import Social
import UniformTypeIdentifiers

@objc(ShareViewController)
class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        handleShare()
    }

    private func handleShare() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (text, _) in
                    if let text = text as? String {
                        self?.openMainApp(with: text)
                    }
                }
                return
            } else if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, _) in
                    if let image = item as? UIImage {
                        UIPasteboard.general.image = image
                        self?.openMainApp(with: "SCAN_SCREENSHOT")
                    } else if let url = item as? URL, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                        UIPasteboard.general.image = image
                        self?.openMainApp(with: "SCAN_SCREENSHOT")
                    }
                }
                return
            }
        }
        
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func openMainApp(with text: String) {
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "splitmoney://add?text=\(encodedText)"
        
        guard let url = URL(string: urlString) else { return }
        
        // Share extensions don't have access to UIApplication.shared.open
        // We use the responder chain to find an object that can open the URL
        let selector = NSSelectorFromString("openURL:")
        var r: UIResponder? = self
        while let next = r {
            if next.responds(to: selector) {
                next.perform(selector, with: url)
                break
            }
            r = next.next
        }
        
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
