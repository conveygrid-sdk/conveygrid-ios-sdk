import UIKit
import SammatiNoticeSDK

final class DemoViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        SammatiNotice.configure(
            SammatiConfiguration(
                clientId: "YOUR_CLIENT_ID",
                origin: "https://demo.example.com",
                debugMode: true
            )
        )

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])

        // 1. Auto / System Mode
        let systemBtn = createButton(title: "Capture Consent (System Mode)", color: .systemBlue) { [weak self] in
            self?.runConsent(preferredMode: "system")
        }
        stack.addArrangedSubview(systemBtn)

        // 2. Force Dark Mode
        let darkBtn = createButton(title: "Capture Consent (Force Dark)", color: .systemIndigo) { [weak self] in
            self?.runConsent(preferredMode: "dark")
        }
        stack.addArrangedSubview(darkBtn)

        // 3. Force Light Mode
        let lightBtn = createButton(title: "Capture Consent (Force Light)", color: .systemTeal) { [weak self] in
            self?.runConsent(preferredMode: "light")
        }
        stack.addArrangedSubview(lightBtn)
    }

    private func createButton(title: String, color: UIColor, action: @escaping () -> Void) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = color
        btn.layer.cornerRadius = 10
        btn.heightAnchor.constraint(equalToConstant: 48).isActive = true
        btn.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return btn
    }

    private func runConsent(preferredMode: String) {
        Task { @MainActor in
            do {
                let theme = NoticeTheme(
                    primaryColor: "#0052CC",
                    secondaryColor: "#10B981",
                    preferredMode: preferredMode
                )
                let result = try await SammatiNotice.captureConsent(
                    options: ConsentOptions(
                        noticeCode: "NOTICE_CODE",
                        email: "user@example.com",
                        mobile: "+919876543210",
                        fullName: "John Doe",
                        theme: theme
                    ),
                    presenter: self
                )
                print("Consent status: \(result.status ?? "unknown")")
            } catch {
                print("Consent error: \(error.localizedDescription)")
            }
        }
    }
}
