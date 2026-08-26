import UIKit
import WebKit

@MainActor
final class GuardianVerificationViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    struct Result {
        let status: String
        let minorConsentProfileId: String?
        let allMandatoryGranted: Bool
        let message: String?
    }

    private let frameURL: String
    private let sessionToken: String
    private var completion: ((Result) -> Void)?
    private var webView: WKWebView!

    static func present(
        frameURL: String,
        sessionToken: String,
        presenter: UIViewController
    ) async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            let vc = GuardianVerificationViewController(frameURL: frameURL, sessionToken: sessionToken) { result in
                continuation.resume(returning: result)
            }
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            presenter.present(nav, animated: true)
        }
    }

    init(frameURL: String, sessionToken: String, completion: @escaping (Result) -> Void) {
        self.frameURL = frameURL
        self.sessionToken = sessionToken
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Guardian Verification"
        view.backgroundColor = .systemBackground

        let content = WKUserContentController()
        let script = """
        (function() {
          window.addEventListener('message', function(event) {
            try {
              if (event && event.data && event.data.type === 'sammati-guardian-realtime') {
                window.webkit.messageHandlers.sammatiGuardian.postMessage(event.data);
              }
            } catch(e) {}
          });
        })();
        """
        content.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        content.add(self, name: "sammatiGuardian")

        let config = WKWebViewConfiguration()
        config.userContentController = content

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(cancel)
        )

        guard var components = URLComponents(string: frameURL) else {
            finish(Result(status: "failed", minorConsentProfileId: nil, allMandatoryGranted: false, message: "Invalid guardian verification URL."))
            return
        }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "session" }
        items.append(URLQueryItem(name: "session", value: sessionToken))
        components.queryItems = items

        guard let url = components.url else {
            finish(Result(status: "failed", minorConsentProfileId: nil, allMandatoryGranted: false, message: "Invalid guardian verification URL."))
            return
        }

        webView.load(URLRequest(url: url))
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "sammatiGuardian",
              let data = message.body as? [String: Any],
              let status = data["status"] as? String else { return }

        guard ["granted", "denied", "failed"].contains(status) else { return }

        finish(Result(
            status: status,
            minorConsentProfileId: data["minorConsentProfileId"] as? String,
            allMandatoryGranted: data["allMandatoryGranted"] as? Bool ?? false,
            message: data["message"] as? String
        ))
    }

    @objc private func cancel() {
        finish(Result(
            status: "failed",
            minorConsentProfileId: nil,
            allMandatoryGranted: false,
            message: "Guardian verification cancelled"
        ))
    }

    private func finish(_ result: Result) {
        guard let completion else { return }
        self.completion = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "sammatiGuardian")
        dismiss(animated: true) {
            completion(result)
        }
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "sammatiGuardian")
    }
}
