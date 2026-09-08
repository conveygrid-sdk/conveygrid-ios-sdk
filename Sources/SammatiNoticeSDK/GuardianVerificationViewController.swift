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

    private var expectedOrigin: String {
        guard let url = URL(string: frameURL),
              let scheme = url.scheme,
              let host = url.host else {
            return ""
        }
        if let port = url.port {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }

    private var expectedHost: String? {
        URL(string: frameURL)?.host?.lowercased()
    }

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

        let targetOrigin = expectedOrigin
        let encodedOrigin: String
        if let data = try? JSONEncoder().encode(targetOrigin),
           let str = String(data: data, encoding: .utf8) {
            encodedOrigin = str
        } else {
            encodedOrigin = "\"\""
        }

        let content = WKUserContentController()
        let script = """
        (function() {
          var expectedOrigin = \(encodedOrigin);
          window.addEventListener('message', function(event) {
            try {
              if (expectedOrigin && event.origin !== expectedOrigin) {
                return;
              }
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
        if let frameHost = message.frameInfo.securityOrigin.host.lowercased() as String?,
           let expected = expectedHost,
           !expected.isEmpty {
            guard frameHost == expected || frameHost.hasSuffix(".\(expected)") else {
                return
            }
        }

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

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        if url.absoluteString == "about:blank" {
            decisionHandler(.allow)
            return
        }

        // Strictly allow only secure web schemes (block javascript:, data:, file:, etc.)
        guard let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme) else {
            decisionHandler(.cancel)
            return
        }

        if let host = url.host?.lowercased(), let expected = expectedHost {
            if host == expected || host.hasSuffix(".\(expected)") {
                decisionHandler(.allow)
                return
            }
        }

        decisionHandler(.cancel)
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
