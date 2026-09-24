import UIKit

@MainActor
final class ConsentViewController: UIViewController {
    private let notice: Notice
    private let theme: NoticeTheme
    private let completion: (Selection) -> Void
    private var selections: [String: Bool] = [:]
    private var checkboxes: [String: UISwitch] = [:]
    private var cardViews: [String: UIView] = [:]
    private var categoryPills: [String: [CategoryPillView]] = [:]
    private var selectAllSwitch: UISwitch?
    private var acceptSelectedBtn: UIButton?
    private var acceptAllBtn: UIButton?
    private var language = "en"

    struct Selection {
        let choices: [ConsentChoice]
        let language: String
        let cancelled: Bool
    }

    static func present(notice: Notice, theme: NoticeTheme? = nil, presenter: UIViewController) async throws -> Selection {
        if notice.showNotice == false {
            let choices = notice.purposes.map { p in
                ConsentChoice(purposeId: p.purposeId ?? "", granted: p.granted)
            }
            return Selection(choices: choices, language: "en", cancelled: false)
        }

        let activeTheme = theme ?? notice.theme ?? NoticeTheme()
        return try await withCheckedThrowingContinuation { continuation in
            let vc = ConsentViewController(notice: notice, theme: activeTheme) { selection in
                continuation.resume(returning: selection)
            }
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .formSheet
            nav.presentationController?.delegate = vc
            if activeTheme.interfaceStyle != .unspecified {
                nav.overrideUserInterfaceStyle = activeTheme.interfaceStyle
                vc.overrideUserInterfaceStyle = activeTheme.interfaceStyle
            }
            if #available(iOS 15.0, *) {
                if let sheet = nav.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.prefersGrabberVisible = true
                    sheet.delegate = vc
                }
            }
            let noticeKey = notice.noticeCode ?? notice.noticeId ?? "unknown"
            SammatiLogger.debug("📱 ConsentViewController modal presenting for notice \(noticeKey)")
            presenter.present(nav, animated: true)
        }
    }

    init(notice: Notice, theme: NoticeTheme? = nil, completion: @escaping (Selection) -> Void) {
        self.notice = notice
        let activeTheme = theme ?? notice.theme ?? NoticeTheme()
        self.theme = activeTheme
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        if activeTheme.interfaceStyle != .unspecified {
            self.overrideUserInterfaceStyle = activeTheme.interfaceStyle
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private var hasFinished = false

    deinit {
        if !hasFinished {
            hasFinished = true
            SammatiLogger.debug("📱 ConsentViewController deallocated without finish -> cancelling")
            completion(Selection(choices: [], language: self.language, cancelled: true))
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !hasFinished && (isBeingDismissed || navigationController?.isBeingDismissed == true) {
            hasFinished = true
            SammatiLogger.debug("📱 ConsentViewController viewDidDisappear dismissal -> cancelling")
            completion(Selection(choices: [], language: self.language, cancelled: true))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if notice.showNotice == false {
            if !hasFinished {
                hasFinished = true
                let choices = notice.purposes.map { ConsentChoice(purposeId: $0.purposeId ?? "", granted: $0.granted) }
                completion(Selection(choices: choices, language: self.language, cancelled: false))
            }
            dismiss(animated: false)
            return
        }

        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = UIColor.adaptive(
            light: UIColor(red: 0.975, green: 0.98, blue: 0.99, alpha: 1.0),
            dark: UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0)
        )
        buildUI()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        refreshAppearance()
    }

    private func refreshAppearance() {
        for (id, _) in cardViews {
            updateCardState(purposeId: id)
        }
        if let alertBox = view.viewWithTag(1001) {
            let alertBorder = UIColor.adaptive(
                light: UIColor(red: 0.996, green: 0.843, blue: 0.667, alpha: 1.0),
                dark: UIColor(red: 0.52, green: 0.28, blue: 0.10, alpha: 1.0)
            )
            alertBox.layer.borderColor = alertBorder.resolvedColor(with: traitCollection).cgColor
        }
        if let panel = view.viewWithTag(1002) {
            let panelBorder = UIColor.adaptive(
                light: UIColor(red: 0.886, green: 0.918, blue: 0.945, alpha: 1.0),
                dark: UIColor(red: 0.20, green: 0.24, blue: 0.31, alpha: 1.0)
            )
            panel.layer.borderColor = panelBorder.resolvedColor(with: traitCollection).cgColor
        }
        if let secBtn = acceptSelectedBtn {
            let secBorderColor = theme.uiSecondaryColor?.withAlphaComponent(0.5) ?? UIColor.adaptive(
                light: UIColor(red: 0.80, green: 0.85, blue: 0.90, alpha: 1.0),
                dark: UIColor(red: 0.30, green: 0.36, blue: 0.45, alpha: 1.0)
            )
            secBtn.layer.borderColor = secBorderColor.resolvedColor(with: traitCollection).cgColor
        }
    }

    private func buildUI() {
        // Main Container
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 0
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // 1. Top Bar / Header
        let topBar = buildTopBar()
        mainStack.addArrangedSubview(topBar)

        // 2. Scrollable Body Content
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        mainStack.addArrangedSubview(scrollView)

        let bodyStack = UIStackView()
        bodyStack.axis = .vertical
        bodyStack.spacing = 16
        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        bodyStack.isLayoutMarginsRelativeArrangement = true
        bodyStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        scrollView.addSubview(bodyStack)

        NSLayoutConstraint.activate([
            bodyStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            bodyStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            bodyStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            bodyStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            bodyStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // 2a. Introduction Text
        let introLabel = UILabel()
        introLabel.text = notice.introductionText ?? "We process your personal data only when it is necessary to provide our services to you. By selecting Accept All or Accept Selected, you consent to the processing of your personal data for the purposes listed below."
        introLabel.numberOfLines = 0
        introLabel.font = .systemFont(ofSize: 14, weight: .regular)
        introLabel.textColor = UIColor.adaptive(
            light: UIColor(red: 0.28, green: 0.33, blue: 0.41, alpha: 1.0),
            dark: UIColor(red: 0.76, green: 0.81, blue: 0.88, alpha: 1.0)
        )
        bodyStack.addArrangedSubview(introLabel)

        // 2b. Mandatory Alert Banner (if mandatory items exist)
        let hasMandatory = notice.purposes.contains { $0.mandatory && !$0.granted }
        if hasMandatory {
            let alertBox = buildMandatoryAlertBanner()
            bodyStack.addArrangedSubview(alertBox)
        }

        // 2c. Purpose Container Panel
        let purposePanel = buildPurposePanel()
        bodyStack.addArrangedSubview(purposePanel)

        // 2d. Footer Text (if any)
        if let footerText = notice.footerText ?? notice.rightsText ?? notice.contactInformation, !footerText.isEmpty {
            let footerLabel = UILabel()
            footerLabel.text = footerText
            footerLabel.numberOfLines = 0
            footerLabel.font = .systemFont(ofSize: 12, weight: .regular)
            footerLabel.textColor = UIColor.adaptive(
                light: UIColor(red: 0.39, green: 0.45, blue: 0.55, alpha: 1.0),
                dark: UIColor(red: 0.62, green: 0.68, blue: 0.76, alpha: 1.0)
            )
            bodyStack.addArrangedSubview(footerLabel)
        }

        // 3. Bottom Pinned Action Bar
        let bottomBar = buildBottomActionBar()
        mainStack.addArrangedSubview(bottomBar)

        updateButtons()
    }

    // MARK: - Top Header Bar
    private func buildTopBar() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.adaptive(
            light: .white,
            dark: UIColor(red: 0.11, green: 0.13, blue: 0.17, alpha: 1.0)
        )
        container.translatesAutoresizingMaskIntoConstraints = false

        let borderBottom = UIView()
        borderBottom.backgroundColor = UIColor.adaptive(
            light: UIColor(red: 0.90, green: 0.92, blue: 0.94, alpha: 1.0),
            dark: UIColor(red: 0.19, green: 0.23, blue: 0.29, alpha: 1.0)
        )
        borderBottom.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(borderBottom)

        // Brand badge / Logo image / label
        let brandLabel = UILabel()
        brandLabel.text = "Sammati"
        brandLabel.font = theme.font(ofSize: 14, weight: .bold)
        brandLabel.textColor = theme.uiPrimaryColor
        brandLabel.translatesAutoresizingMaskIntoConstraints = false

        let logoImageView = UIImageView()
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.isHidden = true

        if let image = theme.logoImage {
            logoImageView.image = image
            logoImageView.isHidden = false
            brandLabel.isHidden = true
        } else if let logoURLString = theme.logoURL,
                  let url = URL(string: logoURLString),
                  url.scheme?.lowercased() == "https" {
            Task {
                let config = URLSessionConfiguration.ephemeral
                config.timeoutIntervalForRequest = 5.0
                let session = URLSession(configuration: config)
                if let (data, response) = try? await session.data(from: url),
                   (response as? HTTPURLResponse)?.statusCode == 200,
                   data.count <= 2 * 1024 * 1024,
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        logoImageView.image = img
                        logoImageView.isHidden = false
                        brandLabel.isHidden = true
                    }
                }
            }
        }

        // Center Title
        let titleLabel = UILabel()
        titleLabel.text = notice.noticeName ?? notice.noticeCode ?? "Consent Notice"
        titleLabel.font = theme.font(ofSize: 16, weight: .bold)
        titleLabel.textColor = UIColor.adaptive(
            light: UIColor(red: 0.05, green: 0.15, blue: 0.25, alpha: 1.0),
            dark: UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
        )
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Close Button
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("✕", for: .normal)
        closeBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        closeBtn.setTitleColor(UIColor.adaptive(
            light: UIColor(red: 0.35, green: 0.40, blue: 0.48, alpha: 1.0),
            dark: UIColor(red: 0.85, green: 0.88, blue: 0.92, alpha: 1.0)
        ), for: .normal)
        closeBtn.backgroundColor = UIColor.adaptive(
            light: UIColor(red: 0.93, green: 0.95, blue: 0.97, alpha: 1.0),
            dark: UIColor(red: 0.18, green: 0.22, blue: 0.28, alpha: 1.0)
        )
        closeBtn.layer.cornerRadius = 16
        closeBtn.clipsToBounds = true
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addAction(UIAction { [weak self] _ in self?.cancel() }, for: .touchUpInside)

        container.addSubview(brandLabel)
        container.addSubview(logoImageView)
        container.addSubview(titleLabel)
        container.addSubview(closeBtn)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 56),

            borderBottom.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            borderBottom.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            borderBottom.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            borderBottom.heightAnchor.constraint(equalToConstant: 1),

            brandLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            brandLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            logoImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            logoImageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            logoImageView.heightAnchor.constraint(equalToConstant: 28),
            logoImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 100),

            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: brandLabel.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeBtn.leadingAnchor, constant: -8),

            closeBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            closeBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 32),
            closeBtn.heightAnchor.constraint(equalToConstant: 32)
        ])

        return container
    }

    // MARK: - Mandatory Alert Banner
    private func buildMandatoryAlertBanner() -> UIView {
        let container = UIView()
        container.tag = 1001
        container.backgroundColor = UIColor.adaptive(
            light: UIColor(red: 1.0, green: 0.968, blue: 0.929, alpha: 1.0),
            dark: UIColor(red: 0.22, green: 0.13, blue: 0.06, alpha: 0.9)
        )
        let alertBorder = UIColor.adaptive(
            light: UIColor(red: 0.996, green: 0.843, blue: 0.667, alpha: 1.0),
            dark: UIColor(red: 0.52, green: 0.28, blue: 0.10, alpha: 1.0)
        )
        container.layer.borderColor = alertBorder.resolvedColor(with: traitCollection).cgColor
        container.layer.borderWidth = 1.0
        container.layer.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let badge = buildPillBadge(
            text: "REQUIRED",
            bg: UIColor.adaptive(light: UIColor(red: 1.0, green: 0.93, blue: 0.84, alpha: 1.0), dark: UIColor(red: 0.38, green: 0.18, blue: 0.08, alpha: 1.0)),
            border: UIColor.adaptive(light: UIColor(red: 0.99, green: 0.80, blue: 0.60, alpha: 1.0), dark: UIColor(red: 0.60, green: 0.30, blue: 0.12, alpha: 1.0)),
            textColor: UIColor.adaptive(light: UIColor(red: 0.76, green: 0.25, blue: 0.05, alpha: 1.0), dark: UIColor(red: 1.0, green: 0.65, blue: 0.40, alpha: 1.0))
        )

        let label = UILabel()
        label.text = "Required purposes must be accepted to proceed."
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.adaptive(
            light: UIColor(red: 0.60, green: 0.20, blue: 0.07, alpha: 1.0),
            dark: UIColor(red: 1.0, green: 0.78, blue: 0.58, alpha: 1.0)
        )
        label.numberOfLines = 0

        stack.addArrangedSubview(badge)
        stack.addArrangedSubview(label)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])

        return container
    }

    // MARK: - Purpose Panel Container
    private func buildPurposePanel() -> UIView {
        let panel = UIView()
        panel.tag = 1002
        panel.backgroundColor = UIColor.adaptive(
            light: UIColor(red: 0.984, green: 0.992, blue: 1.0, alpha: 1.0),
            dark: UIColor(red: 0.11, green: 0.13, blue: 0.17, alpha: 1.0)
        )
        let panelBorder = UIColor.adaptive(
            light: UIColor(red: 0.886, green: 0.918, blue: 0.945, alpha: 1.0),
            dark: UIColor(red: 0.20, green: 0.24, blue: 0.31, alpha: 1.0)
        )
        panel.layer.borderColor = panelBorder.resolvedColor(with: traitCollection).cgColor
        panel.layer.borderWidth = 1.0
        panel.layer.cornerRadius = 14
        panel.clipsToBounds = true
        panel.translatesAutoresizingMaskIntoConstraints = false

        let panelStack = UIStackView()
        panelStack.axis = .vertical
        panelStack.spacing = 12
        panelStack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(panelStack)

        NSLayoutConstraint.activate([
            panelStack.topAnchor.constraint(equalTo: panel.topAnchor),
            panelStack.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            panelStack.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            panelStack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12)
        ])

        // Purpose Panel Header Bar
        let headerBar = UIView()
        headerBar.backgroundColor = UIColor.adaptive(
            light: UIColor(red: 0.957, green: 0.973, blue: 0.984, alpha: 1.0),
            dark: UIColor(red: 0.14, green: 0.16, blue: 0.21, alpha: 1.0)
        )
        headerBar.translatesAutoresizingMaskIntoConstraints = false

        let headerBorder = UIView()
        headerBorder.backgroundColor = UIColor.adaptive(
            light: UIColor(red: 0.91, green: 0.93, blue: 0.95, alpha: 1.0),
            dark: UIColor(red: 0.20, green: 0.24, blue: 0.31, alpha: 1.0)
        )
        headerBorder.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(headerBorder)

        let selectAllStack = UIStackView()
        selectAllStack.axis = .horizontal
        selectAllStack.alignment = .center
        selectAllStack.spacing = 8
        selectAllStack.translatesAutoresizingMaskIntoConstraints = false

        let selectAllToggle = UISwitch()
        selectAllToggle.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        selectAllToggle.onTintColor = theme.uiPrimaryColor
        self.selectAllSwitch = selectAllToggle
        selectAllToggle.addAction(UIAction { [weak self] _ in
            self?.toggleSelectAll(isOn: selectAllToggle.isOn)
        }, for: .valueChanged)

        let selectAllLabel = UILabel()
        selectAllLabel.text = "Select All"
        selectAllLabel.font = theme.font(ofSize: 14, weight: .bold)
        selectAllLabel.textColor = UIColor.adaptive(
            light: UIColor(red: 0.05, green: 0.15, blue: 0.25, alpha: 1.0),
            dark: UIColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1.0)
        )

        selectAllStack.addArrangedSubview(selectAllToggle)
        selectAllStack.addArrangedSubview(selectAllLabel)
        headerBar.addSubview(selectAllStack)

        let countPill = buildPillBadge(
            text: "\(notice.purposes.count) Purposes",
            bg: UIColor.adaptive(light: .white, dark: UIColor(red: 0.18, green: 0.22, blue: 0.28, alpha: 1.0)),
            border: UIColor.adaptive(light: UIColor(red: 0.86, green: 0.90, blue: 0.94, alpha: 1.0), dark: UIColor(red: 0.26, green: 0.31, blue: 0.39, alpha: 1.0)),
            textColor: UIColor.adaptive(light: UIColor(red: 0.39, green: 0.45, blue: 0.55, alpha: 1.0), dark: UIColor(red: 0.78, green: 0.83, blue: 0.89, alpha: 1.0))
        )
        countPill.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(countPill)

        NSLayoutConstraint.activate([
            headerBar.heightAnchor.constraint(equalToConstant: 48),

            headerBorder.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor),
            headerBorder.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor),
            headerBorder.bottomAnchor.constraint(equalTo: headerBar.bottomAnchor),
            headerBorder.heightAnchor.constraint(equalToConstant: 1),

            selectAllStack.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 12),
            selectAllStack.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),

            countPill.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor, constant: -12),
            countPill.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor)
        ])

        panelStack.addArrangedSubview(headerBar)

        // Purpose Cards List Container
        let cardsStack = UIStackView()
        cardsStack.axis = .vertical
        cardsStack.spacing = 10
        cardsStack.isLayoutMarginsRelativeArrangement = true
        cardsStack.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)

        let sortedPurposes = notice.purposes.sorted {
            ($0.displayOrder ?? Int.max, $0.purposeId ?? "") < ($1.displayOrder ?? Int.max, $1.purposeId ?? "")
        }

        for purpose in sortedPurposes {
            let card = buildPurposeCard(for: purpose)
            cardsStack.addArrangedSubview(card)
        }

        panelStack.addArrangedSubview(cardsStack)
        return panel
    }

    // MARK: - Individual Purpose Card
    private func buildPurposeCard(for purpose: Purpose) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 1.0
        card.translatesAutoresizingMaskIntoConstraints = false

        let purposeId = purpose.purposeId ?? ""
        if !purposeId.isEmpty {
            cardViews[purposeId] = card
        }

        let isGranted = purpose.granted
        if isGranted {
            selections[purposeId] = true
        } else {
            selections[purposeId] = purpose.mandatory ? true : false
        }

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 10
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: card.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])

        // Top Row: Title + Badges + Toggle Switch
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.alignment = .top
        topRow.spacing = 8

        let titleStack = UIStackView()
        titleStack.axis = .horizontal
        titleStack.alignment = .center
        titleStack.spacing = 6

        let titleLabel = UILabel()
        titleLabel.text = purpose.purposeName ?? purpose.purposeCode ?? "Purpose"
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = UIColor.adaptive(
            light: UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1.0),
            dark: UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1.0)
        )
        titleLabel.numberOfLines = 0
        titleStack.addArrangedSubview(titleLabel)

        if purpose.mandatory {
            let reqBadge = buildPillBadge(
                text: "REQUIRED",
                bg: UIColor.adaptive(light: UIColor(red: 1.0, green: 0.945, blue: 0.949, alpha: 1.0), dark: UIColor(red: 0.35, green: 0.08, blue: 0.12, alpha: 0.8)),
                border: UIColor.adaptive(light: UIColor(red: 0.996, green: 0.804, blue: 0.827, alpha: 1.0), dark: UIColor(red: 0.60, green: 0.15, blue: 0.22, alpha: 1.0)),
                textColor: UIColor.adaptive(light: UIColor(red: 0.745, green: 0.071, blue: 0.235, alpha: 1.0), dark: UIColor(red: 1.0, green: 0.65, blue: 0.72, alpha: 1.0))
            )
            titleStack.addArrangedSubview(reqBadge)
        }

        if isGranted {
            let grantedBadge = buildPillBadge(
                text: "CONSENTED",
                bg: UIColor.adaptive(light: UIColor(red: 0.925, green: 0.992, blue: 0.961, alpha: 1.0), dark: UIColor(red: 0.05, green: 0.25, blue: 0.18, alpha: 0.8)),
                border: UIColor.adaptive(light: UIColor(red: 0.655, green: 0.953, blue: 0.816, alpha: 1.0), dark: UIColor(red: 0.12, green: 0.50, blue: 0.35, alpha: 1.0)),
                textColor: UIColor.adaptive(light: UIColor(red: 0.016, green: 0.471, blue: 0.341, alpha: 1.0), dark: UIColor(red: 0.45, green: 0.92, blue: 0.72, alpha: 1.0))
            )
            titleStack.addArrangedSubview(grantedBadge)
        }

        topRow.addArrangedSubview(titleStack)

        let toggle = UISwitch()
        toggle.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        toggle.onTintColor = theme.uiPrimaryColor
        toggle.isOn = selections[purposeId] ?? false
        toggle.isEnabled = !isGranted

        if !purposeId.isEmpty {
            checkboxes[purposeId] = toggle
            toggle.addAction(UIAction { [weak self, weak toggle] _ in
                guard let self, let toggle else { return }
                self.selections[purposeId] = toggle.isOn
                self.updateCardState(purposeId: purposeId)
                self.updateButtons()
            }, for: .valueChanged)
        }

        topRow.addArrangedSubview(toggle)
        contentStack.addArrangedSubview(topRow)

        // Description
        if let description = purpose.purposeDescription, !description.isEmpty {
            let descLabel = UILabel()
            descLabel.text = description
            descLabel.font = .systemFont(ofSize: 13, weight: .regular)
            descLabel.textColor = UIColor.adaptive(
                light: UIColor(red: 0.39, green: 0.45, blue: 0.55, alpha: 1.0),
                dark: UIColor(red: 0.68, green: 0.74, blue: 0.82, alpha: 1.0)
            )
            descLabel.numberOfLines = 0
            contentStack.addArrangedSubview(descLabel)
        }

        // Data Categories Pills with PillFlowView
        if !purpose.categories.isEmpty {
            let catContainer = UIStackView()
            catContainer.axis = .vertical
            catContainer.spacing = 6

            let catLabel = UILabel()
            catLabel.text = "DATA CATEGORIES"
            catLabel.font = .systemFont(ofSize: 10, weight: .bold)
            catLabel.textColor = UIColor.adaptive(
                light: UIColor(red: 0.48, green: 0.54, blue: 0.62, alpha: 1.0),
                dark: UIColor(red: 0.60, green: 0.66, blue: 0.75, alpha: 1.0)
            )
            catContainer.addArrangedSubview(catLabel)

            let flowView = PillFlowView()
            flowView.horizontalSpacing = 8
            flowView.verticalSpacing = 8

            let sortedCat = purpose.categories.sorted {
                ($0.displayOrder ?? Int.max, $0.categoryId ?? "") < ($1.displayOrder ?? Int.max, $1.categoryId ?? "")
            }

            var pills: [CategoryPillView] = []
            for cat in sortedCat {
                if let name = cat.categoryName ?? cat.categoryCode {
                    let pill = CategoryPillView(name: name, primaryColor: theme.uiPrimaryColor)
                    pills.append(pill)
                }
            }
            if !purposeId.isEmpty {
                categoryPills[purposeId] = pills
            }
            flowView.setPills(pills)
            catContainer.addArrangedSubview(flowView)
            contentStack.addArrangedSubview(catContainer)
        }

        updateCardState(purposeId: purposeId)
        return card
    }

    private func updateCardState(purposeId: String) {
        guard let card = cardViews[purposeId] else { return }
        let isSelected = selections[purposeId] == true
        let purpose = notice.purposes.first { $0.purposeId == purposeId }
        let isGranted = purpose?.granted ?? false

        if let pills = categoryPills[purposeId] {
            for pill in pills {
                pill.setSelectedState(isSelected)
            }
        }

        let isDark = traitCollection.userInterfaceStyle == .dark

        if isGranted {
            card.backgroundColor = isDark
                ? UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1.0)
                : UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1.0)
            card.layer.borderColor = (isDark
                ? UIColor(red: 0.20, green: 0.24, blue: 0.30, alpha: 1.0)
                : UIColor(red: 0.88, green: 0.90, blue: 0.92, alpha: 1.0)).cgColor
        } else if isSelected {
            card.backgroundColor = isDark
                ? theme.uiPrimaryColor.withAlphaComponent(0.18)
                : theme.uiPrimaryColor.withAlphaComponent(0.06)
            card.layer.borderColor = (isDark
                ? theme.uiPrimaryColor.withAlphaComponent(0.65)
                : theme.uiPrimaryColor.withAlphaComponent(0.40)).cgColor
        } else {
            card.backgroundColor = isDark
                ? UIColor(red: 0.14, green: 0.16, blue: 0.21, alpha: 1.0)
                : .white
            card.layer.borderColor = (isDark
                ? UIColor(red: 0.22, green: 0.26, blue: 0.33, alpha: 1.0)
                : UIColor(red: 0.886, green: 0.910, blue: 0.941, alpha: 1.0)).cgColor
        }
    }

    // MARK: - Bottom Pinned Action Bar
    private func buildBottomActionBar() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.adaptive(
            light: .white,
            dark: UIColor(red: 0.11, green: 0.13, blue: 0.17, alpha: 1.0)
        )
        container.translatesAutoresizingMaskIntoConstraints = false

        let borderTop = UIView()
        borderTop.backgroundColor = UIColor.adaptive(
            light: UIColor(red: 0.90, green: 0.92, blue: 0.94, alpha: 1.0),
            dark: UIColor(red: 0.19, green: 0.23, blue: 0.29, alpha: 1.0)
        )
        borderTop.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(borderTop)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let buttonsRow = UIStackView()
        buttonsRow.axis = .horizontal
        buttonsRow.distribution = .fillEqually
        buttonsRow.spacing = 10

        // Secondary Action Button (Accept Selected)
        let secondaryBtn = UIButton(type: .system)
        secondaryBtn.setTitle("Accept Selected", for: .normal)
        secondaryBtn.titleLabel?.font = theme.font(ofSize: 14, weight: .bold)
        let secTextColor = theme.uiSecondaryColor ?? UIColor.adaptive(
            light: UIColor(red: 0.03, green: 0.29, blue: 0.38, alpha: 1.0),
            dark: UIColor(red: 0.90, green: 0.93, blue: 0.98, alpha: 1.0)
        )
        secondaryBtn.setTitleColor(secTextColor, for: .normal)
        secondaryBtn.backgroundColor = UIColor.adaptive(
            light: .white,
            dark: UIColor(red: 0.16, green: 0.19, blue: 0.25, alpha: 1.0)
        )
        let secBorderColor = theme.uiSecondaryColor?.withAlphaComponent(0.5) ?? UIColor.adaptive(
            light: UIColor(red: 0.80, green: 0.85, blue: 0.90, alpha: 1.0),
            dark: UIColor(red: 0.30, green: 0.36, blue: 0.45, alpha: 1.0)
        )
        secondaryBtn.layer.borderColor = secBorderColor.resolvedColor(with: traitCollection).cgColor
        secondaryBtn.layer.borderWidth = 1.0
        secondaryBtn.layer.cornerRadius = 10
        secondaryBtn.heightAnchor.constraint(equalToConstant: 46).isActive = true
        secondaryBtn.addAction(UIAction { [weak self] _ in self?.submit(all: false) }, for: .touchUpInside)
        self.acceptSelectedBtn = secondaryBtn

        // Primary Action Button (Accept All)
        let primaryBtn = UIButton(type: .system)
        primaryBtn.setTitle("Accept All", for: .normal)
        primaryBtn.titleLabel?.font = theme.font(ofSize: 14, weight: .bold)
        primaryBtn.setTitleColor(.white, for: .normal)
        primaryBtn.backgroundColor = theme.uiPrimaryColor
        primaryBtn.layer.cornerRadius = 10
        primaryBtn.heightAnchor.constraint(equalToConstant: 46).isActive = true
        primaryBtn.addAction(UIAction { [weak self] _ in self?.submit(all: true) }, for: .touchUpInside)
        self.acceptAllBtn = primaryBtn

        buttonsRow.addArrangedSubview(secondaryBtn)
        buttonsRow.addArrangedSubview(primaryBtn)
        stack.addArrangedSubview(buttonsRow)

        // Security Credit
        let securityLabel = UILabel()
        securityLabel.text = "Secured by Sammati Consent Gateway"
        securityLabel.font = .systemFont(ofSize: 11, weight: .medium)
        securityLabel.textColor = UIColor.adaptive(
            light: UIColor(red: 0.50, green: 0.56, blue: 0.64, alpha: 1.0),
            dark: UIColor(red: 0.65, green: 0.70, blue: 0.78, alpha: 1.0)
        )
        securityLabel.textAlignment = .center
        stack.addArrangedSubview(securityLabel)

        NSLayoutConstraint.activate([
            borderTop.topAnchor.constraint(equalTo: container.topAnchor),
            borderTop.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            borderTop.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            borderTop.heightAnchor.constraint(equalToConstant: 1),

            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        return container
    }

    // MARK: - Helper UI Builders
    private func buildPillBadge(text: String, bg: UIColor, border: UIColor, textColor: UIColor) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = textColor
        label.translatesAutoresizingMaskIntoConstraints = false

        let pill = DynamicPillView(bgColor: bg, borderColor: border)
        pill.layer.cornerRadius = 8
        pill.layer.borderWidth = 1.0
        pill.clipsToBounds = true
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -6)
        ])

        pill.setContentHuggingPriority(.required, for: .horizontal)
        pill.setContentHuggingPriority(.required, for: .vertical)
        pill.setContentCompressionResistancePriority(.required, for: .horizontal)
        pill.setContentCompressionResistancePriority(.required, for: .vertical)

        return pill
    }

    // MARK: - Logic & Actions
    private func toggleSelectAll(isOn: Bool) {
        for (id, toggle) in checkboxes {
            guard toggle.isEnabled else { continue }
            toggle.setOn(isOn, animated: true)
            selections[id] = isOn
            updateCardState(purposeId: id)
        }
        updateButtons()
    }

    private func mandatorySatisfied() -> Bool {
        let mandatoryUnresolved = notice.purposes.filter { $0.mandatory && !$0.granted }
        if mandatoryUnresolved.isEmpty { return true }
        return mandatoryUnresolved.allSatisfy {
            selections[$0.purposeId ?? ""] == true
        }
    }

    private func hasAnySelected() -> Bool {
        notice.purposes.contains { purpose in
            purpose.granted || (selections[purpose.purposeId ?? ""] == true)
        }
    }

    private func allSelected() -> Bool {
        let available = notice.purposes.filter { !$0.granted }
        if available.isEmpty { return true }
        return available.allSatisfy { selections[$0.purposeId ?? ""] == true }
    }

    private func updateButtons() {
        let mandatoryOK = mandatorySatisfied()
        let anySelected = hasAnySelected()
        let allOn = allSelected()

        selectAllSwitch?.setOn(allOn, animated: true)

        let selectedEnabled = mandatoryOK && anySelected
        acceptSelectedBtn?.isEnabled = selectedEnabled
        acceptSelectedBtn?.alpha = selectedEnabled ? 1.0 : 0.55

        acceptAllBtn?.isEnabled = true
        acceptAllBtn?.alpha = 1.0
    }

    private func submit(all: Bool) {
        if !mandatorySatisfied() {
            showError("Please select all required purposes.")
            return
        }
        if !all && !hasAnySelected() {
            showError("Please select at least one purpose.")
            return
        }

        let choices = notice.purposes.compactMap { purpose -> ConsentChoice? in
            guard let id = purpose.purposeId else { return nil }
            let granted = purpose.granted || (all ? true : (selections[id] ?? false))
            return ConsentChoice(purposeId: id, granted: granted)
        }

        guard !hasFinished else { return }
        hasFinished = true
        dismiss(animated: true) { [completion, language = self.language] in
            completion(Selection(choices: choices, language: language, cancelled: false))
        }
    }

    @objc private func cancel() {
        guard !hasFinished else { return }
        hasFinished = true
        SammatiLogger.debug("📱 User tapped cancel/close button in ConsentViewController")
        dismiss(animated: true) { [completion, language = self.language] in
            completion(Selection(choices: [], language: language, cancelled: true))
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Consent Required", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension ConsentViewController: UIAdaptivePresentationControllerDelegate, UISheetPresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if !hasFinished {
            hasFinished = true
            SammatiLogger.debug("📱 User dragged down to dismiss sheet -> presentationControllerDidDismiss called")
            completion(Selection(choices: [], language: self.language, cancelled: true))
        }
    }
}

// MARK: - Dynamic Supporting Views

final class DynamicPillView: UIView {
    private let dynamicBgColor: UIColor
    private let dynamicBorderColor: UIColor

    init(bgColor: UIColor, borderColor: UIColor) {
        self.dynamicBgColor = bgColor
        self.dynamicBorderColor = borderColor
        super.init(frame: .zero)
        updateColors()
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateColors() {
        backgroundColor = dynamicBgColor
        layer.borderColor = dynamicBorderColor.resolvedColor(with: traitCollection).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateColors()
    }
}

final class CategoryPillView: UIView {
    private let label = UILabel()
    private var isCardSelected: Bool = false
    private let primaryColor: UIColor

    init(name: String, primaryColor: UIColor = UIColor(red: 0.0, green: 0.357, blue: 0.929, alpha: 1.0)) {
        self.primaryColor = primaryColor
        super.init(frame: .zero)
        setupUI(name: name)
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI(name: String) {
        layer.cornerRadius = 6
        layer.borderWidth = 1.0
        clipsToBounds = true

        label.text = name
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
    }

    override var intrinsicContentSize: CGSize {
        let labelSize = label.intrinsicContentSize
        return CGSize(width: labelSize.width + 20, height: max(26, labelSize.height + 10))
    }

    func setSelectedState(_ selected: Bool) {
        self.isCardSelected = selected
        updateAppearance()
    }

    func updateAppearance() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        if isCardSelected {
            if isDark {
                backgroundColor = primaryColor.withAlphaComponent(0.20)
                layer.borderColor = primaryColor.withAlphaComponent(0.45).cgColor
                label.textColor = UIColor(red: 0.70, green: 0.85, blue: 1.0, alpha: 1.0)
            } else {
                backgroundColor = primaryColor.withAlphaComponent(0.08)
                layer.borderColor = primaryColor.withAlphaComponent(0.28).cgColor
                label.textColor = primaryColor
            }
        } else {
            if isDark {
                backgroundColor = UIColor(red: 0.16, green: 0.20, blue: 0.26, alpha: 1.0)
                layer.borderColor = UIColor(red: 0.26, green: 0.32, blue: 0.42, alpha: 1.0).cgColor
                label.textColor = UIColor(red: 0.88, green: 0.92, blue: 0.96, alpha: 1.0)
            } else {
                backgroundColor = UIColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1.0)
                layer.borderColor = UIColor(red: 0.84, green: 0.88, blue: 0.93, alpha: 1.0).cgColor
                label.textColor = UIColor(red: 0.22, green: 0.28, blue: 0.38, alpha: 1.0)
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAppearance()
    }
}

final class PillFlowView: UIView {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8
    private var pillViews: [UIView] = []
    private var heightConstraint: NSLayoutConstraint?

    func setPills(_ pills: [UIView]) {
        pillViews.forEach { $0.removeFromSuperview() }
        pillViews = pills
        for pill in pillViews {
            addSubview(pill)
        }
        let estHeight: CGFloat = pills.isEmpty ? 0 : 28
        if let hc = heightConstraint {
            hc.constant = estHeight
        } else {
            let hc = heightAnchor.constraint(equalToConstant: estHeight)
            hc.priority = UILayoutPriority(999)
            hc.isActive = true
            heightConstraint = hc
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let availableWidth = bounds.width
        guard availableWidth > 0 else { return }

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for pill in pillViews {
            let pillSize = pill.intrinsicContentSize
            if currentX + pillSize.width > availableWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + verticalSpacing
                lineHeight = 0
            }
            pill.frame = CGRect(x: currentX, y: currentY, width: pillSize.width, height: pillSize.height)
            lineHeight = max(lineHeight, pillSize.height)
            currentX += pillSize.width + horizontalSpacing
        }

        let totalHeight = currentY + lineHeight
        if let hc = heightConstraint, hc.constant != totalHeight {
            hc.constant = totalHeight
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        let availableWidth = bounds.width > 0 ? bounds.width : (superview?.bounds.width ?? 320)
        guard availableWidth > 0 else { return CGSize(width: 320, height: 28) }

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for pill in pillViews {
            let pillSize = pill.intrinsicContentSize
            if currentX + pillSize.width > availableWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + verticalSpacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, pillSize.height)
            currentX += pillSize.width + horizontalSpacing
        }
        return CGSize(width: availableWidth, height: max(28, currentY + lineHeight))
    }
}

// MARK: - Xcode Canvas Live Preview
#if DEBUG
import SwiftUI

@available(iOS 13.0, *)
struct ConsentViewController_Preview: UIViewControllerRepresentable {
    var isDarkMode: Bool = false

    func makeUIViewController(context: Context) -> UINavigationController {
        let dummyNotice = Notice(
            noticeId: "preview-1",
            noticeCode: "LOGISTICS",
            version: "1.0",
            noticeName: "Logistics Policy Consent",
            introductionText: "We value your privacy. This consent notice explains how your personal data will be collected, used, stored and processed to provide you with our service. Please review the information carefully and provide your consent.",
            footerText: "Please review your information carefully and provide your consent where applications.",
            rightsText: nil,
            contactInformation: nil,
            showNotice: true,
            message: nil,
            purposes: [
                Purpose(
                    purposeId: "p1",
                    purposeCode: "MARKETING_EMAIL",
                    purposeName: "Marketing Email",
                    purposeDescription: nil,
                    isMandatory: true,
                    alreadyGranted: false,
                    displayOrder: 1,
                    categories: [
                        PurposeCategory(categoryId: "c1", categoryCode: "EMAIL", categoryName: "Email", displayOrder: 1)
                    ]
                ),
                Purpose(
                    purposeId: "p2",
                    purposeCode: "PROMOTION_OFFERS",
                    purposeName: "Promotion & Offers",
                    purposeDescription: nil,
                    isMandatory: false,
                    alreadyGranted: false,
                    displayOrder: 2,
                    categories: [
                        PurposeCategory(categoryId: "c2", categoryCode: "DOB", categoryName: "DOB", displayOrder: 1),
                        PurposeCategory(categoryId: "c3", categoryCode: "FULL_NAME", categoryName: "Full Name", displayOrder: 2),
                        PurposeCategory(categoryId: "c4", categoryCode: "MOBILE_NO", categoryName: "Mobile No", displayOrder: 3)
                    ]
                )
            ]
        )

        let theme = NoticeTheme(
            primaryColor: "#0052CC",
            secondaryColor: "#10B981",
            preferredMode: isDarkMode ? "dark" : "light"
        )
        let vc = ConsentViewController(notice: dummyNotice, theme: theme) { _ in }
        let nav = UINavigationController(rootViewController: vc)
        nav.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

@available(iOS 17.0, *)
#Preview("Light Mode") {
    ConsentViewController_Preview(isDarkMode: false)
}

@available(iOS 17.0, *)
#Preview("Dark Mode") {
    ConsentViewController_Preview(isDarkMode: true)
        .preferredColorScheme(.dark)
}
#endif
