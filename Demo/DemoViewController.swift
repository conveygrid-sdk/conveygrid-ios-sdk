import UIKit
import SammatiNoticeSDK

final class DemoViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        SammatiNotice.configure(
            SammatiConfiguration(
                clientId: "YOUR_CLIENT_ID",
                apiBaseURL: URL(string: "https://YOUR_API_BASE")!,
                environment: .sandbox
            )
        )

        let button = UIButton(type: .system)
        button.setTitle("Capture Consent", for: .normal)
        button.addAction(UIAction { [weak self] _ in
            Task { @MainActor in
                do {
                    let result = try await SammatiNotice.captureConsent(
                        options: ConsentOptions(
                            noticeCode: "NOTICE_CODE",
                            fullName: "Demo User",
                            email: "demo@example.com",
                            mobile: "9999999999"
                        ),
                        presenter: self
                    )
                    print(result.status ?? "unknown")
                } catch {
                    print(error.localizedDescription)
                }
            }
        }, for: .touchUpInside)

        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
