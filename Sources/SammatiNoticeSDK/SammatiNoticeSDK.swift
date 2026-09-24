import Foundation
import UIKit

public enum SammatiEnvironment: Sendable {
    case sandbox
    case production

    internal var defaultBaseURL: URL {
        switch self {
        case .sandbox:
            return URL(string: "https://conveygridapidev.rysun.in")!
        case .production:
            return URL(string: "https://samatigridapi.rysun.in")!
        }
    }
}

public struct SammatiConfiguration {
    public static let defaultEnvironment: SammatiEnvironment = .sandbox

    public let clientId: String
    public let origin: String
    public let environment: SammatiEnvironment
    public let theme: NoticeTheme?
    public let debugMode: Bool

    internal let apiBaseURL: URL

    public init(
        clientId: String,
        origin: String,
        environment: SammatiEnvironment = SammatiConfiguration.defaultEnvironment,
        theme: NoticeTheme? = nil,
        debugMode: Bool = {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }()
    ) {
        self.clientId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.origin = origin.trimmingCharacters(in: .whitespacesAndNewlines)
        self.environment = environment
        self.theme = theme
        self.debugMode = debugMode
        self.apiBaseURL = environment.defaultBaseURL
    }

    internal init(
        clientId: String,
        origin: String,
        apiBaseURL: URL,
        environment: SammatiEnvironment = SammatiConfiguration.defaultEnvironment,
        theme: NoticeTheme? = nil,
        debugMode: Bool = {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }()
    ) {
        self.clientId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.origin = origin.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiBaseURL = apiBaseURL
        self.environment = environment
        self.theme = theme
        self.debugMode = debugMode
    }
}

public enum SammatiSDKError: LocalizedError {
    case notConfigured
    case invalidConfiguration(String)
    case invalidNoticeCode
    case invalidDateOfBirth
    case guardianRequired
    case guardianNameRequired
    case guardianRelationshipRequired
    case guardianContactRequired
    case minorFullNameRequired
    case adultOnlyNotice
    case noPendingConsent
    case consentLinkExpired
    case invalidGuardianFrameURL
    case guardianVerificationFailed(String)
    case invalidResponse
    case serverError(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "SammatiNoticeSDK is not configured."
        case .invalidConfiguration(let message): return "Invalid configuration: \(message)"
        case .invalidNoticeCode: return "noticeCode is required."
        case .invalidDateOfBirth: return "dateOfBirth must be a valid date in YYYY-MM-DD format."
        case .guardianRequired: return "Guardian details are required for minors."
        case .guardianNameRequired: return "guardianName is required for minors."
        case .guardianRelationshipRequired: return "guardian relationshipId or relationshipCode is required for minors."
        case .guardianContactRequired: return "guardianEmail or guardianMobile is required."
        case .minorFullNameRequired: return "fullName is required for minors."
        case .adultOnlyNotice: return "This notice does not support minors."
        case .noPendingConsent: return "No pending consent link exists in the current session."
        case .consentLinkExpired: return "The consent link window has expired."
        case .invalidGuardianFrameURL: return "Invalid guardian realtime verification URL."
        case .guardianVerificationFailed(let message): return message
        case .invalidResponse: return "The server returned an invalid response."
        case .serverError(let message): return message
        case .cancelled: return "The consent flow was cancelled."
        }
    }
}

public struct Guardian: Codable, Sendable {
    public let guardianName: String
    public let guardianEmail: String?
    public let guardianMobile: String?
    public let relationshipCode: String?
    public let relationshipId: String?

    public init(
        guardianName: String,
        guardianEmail: String? = nil,
        guardianMobile: String? = nil,
        relationshipCode: String? = nil,
        relationshipId: String? = nil
    ) {
        self.guardianName = guardianName
        self.guardianEmail = guardianEmail
        self.guardianMobile = guardianMobile
        self.relationshipCode = relationshipCode
        self.relationshipId = relationshipId
    }
}

public struct ConsentOptions: Sendable {
    public let noticeCode: String?
    public let consentLink: String?
    public let email: String?
    public let mobile: String?
    public let fullName: String?
    public let dateOfBirth: String?
    public let guardian: Guardian?
    public let referenceId: String?
    public let sessionId: String?
    public let subjectRef: String?
    public let language: String?
    public let purposeCode: String?
    public let purposeCodes: [String]
    public let forceDisplay: Bool
    public let skipIfValid: Bool
    public let theme: NoticeTheme?

    public init(
        noticeCode: String? = nil,
        consentLink: String? = nil,
        email: String? = nil,
        mobile: String? = nil,
        fullName: String? = nil,
        dateOfBirth: String? = nil,
        guardian: Guardian? = nil,
        referenceId: String? = nil,
        sessionId: String? = nil,
        subjectRef: String? = nil,
        language: String? = nil,
        purposeCode: String? = nil,
        purposeCodes: [String] = [],
        forceDisplay: Bool = false,
        skipIfValid: Bool = true,
        theme: NoticeTheme? = nil
    ) {
        self.noticeCode = noticeCode
        self.consentLink = consentLink
        self.email = email
        self.mobile = mobile
        self.fullName = fullName
        self.dateOfBirth = dateOfBirth
        self.guardian = guardian
        self.referenceId = referenceId
        self.sessionId = sessionId
        self.subjectRef = subjectRef
        self.language = language
        self.purposeCode = purposeCode
        self.purposeCodes = purposeCodes
        self.forceDisplay = forceDisplay
        self.skipIfValid = skipIfValid
        self.theme = theme
    }

    /// Convenience initializer for shareable public consent links or tokens
    public init(
        consentLink: String,
        email: String? = nil,
        mobile: String? = nil,
        fullName: String? = nil,
        dateOfBirth: String? = nil,
        guardian: Guardian? = nil,
        referenceId: String? = nil,
        sessionId: String? = nil,
        subjectRef: String? = nil,
        language: String? = nil,
        forceDisplay: Bool = false,
        skipIfValid: Bool = true,
        theme: NoticeTheme? = nil
    ) {
        self.init(
            noticeCode: nil,
            consentLink: consentLink,
            email: email,
            mobile: mobile,
            fullName: fullName,
            dateOfBirth: dateOfBirth,
            guardian: guardian,
            referenceId: referenceId,
            sessionId: sessionId,
            subjectRef: subjectRef,
            language: language,
            forceDisplay: forceDisplay,
            skipIfValid: skipIfValid,
            theme: theme
        )
    }

    /// Resolves the link token if options provide a public consent link or long token string
    public var resolvedLinkToken: String? {
        if let consentLink, !consentLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ConsentOptions.extractToken(from: consentLink)
        }
        if let noticeCode, ConsentOptions.isLinkOrToken(noticeCode) {
            return ConsentOptions.extractToken(from: noticeCode)
        }
        return nil
    }

    public static func isLinkOrToken(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed.contains("/consent/link") || trimmed.contains("token=")
        }
        if trimmed.count >= 40 && !trimmed.contains(" ") && !trimmed.contains("/") {
            return true
        }
        return false
    }

    public static func extractToken(from string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let tokenQuery = components.queryItems?.first(where: { $0.name == "token" })?.value, !tokenQuery.isEmpty {
                return tokenQuery
            }
            let segments = components.path.split(separator: "/").map(String.init)
            if let linkIndex = segments.firstIndex(of: "link"), linkIndex + 1 < segments.count {
                return segments[linkIndex + 1]
            }
        }
        if let range = trimmed.range(of: "/link/") {
            let sub = trimmed[range.upperBound...]
            let token = sub.components(separatedBy: "?").first?.components(separatedBy: "#").first ?? String(sub)
            if !token.isEmpty {
                return token
            }
        }
        return trimmed
    }
}

public struct ConsentChoice: Codable, Sendable {
    public let purposeId: String
    public let granted: Bool

    public init(purposeId: String, granted: Bool) {
        self.purposeId = purposeId
        self.granted = granted
    }

    enum CodingKeys: String, CodingKey {
        case purposeId = "purpose_id"
        case granted
    }
}

public struct ConsentResult: Sendable {
    public let artifactId: String?
    public let subjectId: String?
    public let allMandatoryGranted: Bool
    public let preferenceToken: String?
    public let status: String?
    public let linkRequired: Bool
    public let linkExpiresAt: Date?
    public let dpType: String?
    public let minorConsentProfileId: String?
    public let minorDpId: String?
    public let invitationStatus: String?
    public let invitationLink: String?
    public let guardianVerificationMode: String
    public let guardianSessionToken: String?
    public let guardianFrameUrl: String?
    public let guardianVerificationPending: Bool
    public let realtimeStatus: String?
    public let showNotice: Bool
    public let skipped: Bool
    public let cancelled: Bool
    public let message: String?

    public init(
        artifactId: String? = nil,
        subjectId: String? = nil,
        allMandatoryGranted: Bool = false,
        preferenceToken: String? = nil,
        status: String? = nil,
        linkRequired: Bool = false,
        linkExpiresAt: Date? = nil,
        dpType: String? = nil,
        minorConsentProfileId: String? = nil,
        minorDpId: String? = nil,
        invitationStatus: String? = nil,
        invitationLink: String? = nil,
        guardianVerificationMode: String = "INVITATION_LINK",
        guardianSessionToken: String? = nil,
        guardianFrameUrl: String? = nil,
        guardianVerificationPending: Bool = false,
        realtimeStatus: String? = nil,
        showNotice: Bool = true,
        skipped: Bool = false,
        cancelled: Bool = false,
        message: String? = nil
    ) {
        self.artifactId = artifactId
        self.subjectId = subjectId
        self.allMandatoryGranted = allMandatoryGranted
        self.preferenceToken = preferenceToken
        self.status = status
        self.linkRequired = linkRequired
        self.linkExpiresAt = linkExpiresAt
        self.dpType = dpType
        self.minorConsentProfileId = minorConsentProfileId
        self.minorDpId = minorDpId
        self.invitationStatus = invitationStatus
        self.invitationLink = invitationLink
        self.guardianVerificationMode = guardianVerificationMode
        self.guardianSessionToken = guardianSessionToken
        self.guardianFrameUrl = guardianFrameUrl
        self.guardianVerificationPending = guardianVerificationPending
        self.realtimeStatus = realtimeStatus
        self.showNotice = showNotice
        self.skipped = skipped
        self.cancelled = cancelled
        self.message = message
    }
}

public struct ConsentHandle: Sendable {
    public fileprivate(set) var result: ConsentResult
    private let linker: @Sendable (String) async throws -> ConsentResult

    public var artifactId: String? { result.artifactId }
    public var invitationLink: String? { result.invitationLink }

    fileprivate init(result: ConsentResult, linker: @escaping @Sendable (String) async throws -> ConsentResult) {
        self.result = result
        self.linker = linker
    }

    public mutating func complete(referenceId: String) async throws -> ConsentResult {
        result = try await linker(referenceId)
        return result
    }
}

public final class SammatiNotice {
    public static let shared = SammatiNotice()

    private var configuration: SammatiConfiguration?
    private let session = SessionStore()

    private init() {}

    public static func configure(_ configuration: SammatiConfiguration) {
        shared.configuration = configuration
        SammatiLogger.isDebugEnabled = configuration.debugMode || SammatiLogger.isDebugEnabled
        SammatiLogger.debug("Configured SammatiNoticeSDK (clientId: \(configuration.clientId), origin: \(configuration.origin), env: \(configuration.environment), debugMode: \(SammatiLogger.isDebugEnabled))")
    }

    public static func configure(
        clientId: String,
        origin: String,
        environment: SammatiEnvironment = SammatiConfiguration.defaultEnvironment,
        theme: NoticeTheme? = nil,
        debugMode: Bool = {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }()
    ) {
        configure(
            SammatiConfiguration(
                clientId: clientId,
                origin: origin,
                environment: environment,
                theme: theme,
                debugMode: debugMode
            )
        )
    }

    /// Enables or disables verbose debug logging to the console (including HTTP requests and responses).
    public static func enableDebugLogging(_ enabled: Bool = true) {
        SammatiLogger.isDebugEnabled = enabled
        SammatiLogger.info("Debug logging is \(enabled ? "ENABLED" : "DISABLED").")
    }

    /// Clears any cached consent statuses and pending links stored on device.
    public static func clearConsentCache() {
        GrantedConsentStore.clear()
        PendingLinkStore.clear()
        SammatiLogger.info("Cleared local consent cache.")
    }

    public static func getSessionId() -> String {
        shared.session.sessionId
    }

    public static func getAnonymousId() -> String {
        shared.session.sessionId
    }

    public static func isMinorDateOfBirth(_ value: String) -> Bool {
        guard let date = DateParser.parse(value) else { return false }
        return AgeCalculator.isMinor(date)
    }

    @MainActor
    public static func captureConsent(
        options: ConsentOptions,
        presenter: UIViewController? = nil
    ) async throws -> ConsentResult {
        try await shared.capture(options: options, presenter: presenter)
    }

    public static func validateConsent(
        identity: ConsentIdentity,
        purposeCode: String,
        noticeCode: String? = nil
    ) async throws -> ConsentValidation {
        try await shared.validate(identity: identity, purposeCode: purposeCode, noticeCode: noticeCode)
    }

    @MainActor
    public static func show(
        noticeCode: String,
        subjectRef: String? = nil,
        language: String? = nil,
        presenter: UIViewController
    ) async throws -> ConsentResult {
        let options = ConsentOptions(
            noticeCode: noticeCode,
            subjectRef: subjectRef,
            language: language
        )
        return try await shared.capture(options: options, presenter: presenter)
    }

    public static func resumePendingLink(referenceId: String) async throws -> ConsentResult {
        try await shared.resume(referenceId: referenceId)
    }

    @MainActor
    private func capture(options: ConsentOptions, presenter: UIViewController?) async throws -> ConsentResult {
        let config = try validatedConfiguration()
        let resolvedToken = options.resolvedLinkToken
        let hasNoticeCode = options.noticeCode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        guard resolvedToken != nil || hasNoticeCode else {
            throw SammatiSDKError.invalidNoticeCode
        }

        let dob = try DateParser.normalized(options.dateOfBirth)
        let isMinor = DateParser.parse(options.dateOfBirth).map(AgeCalculator.isMinor) ?? false

        if isMinor {
            guard let guardian = options.guardian else { throw SammatiSDKError.guardianRequired }
            try GuardianValidator.validate(guardian)
            guard let fullName = options.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !fullName.isEmpty else {
                throw SammatiSDKError.minorFullNameRequired
            }
        }

        let identity = ConsentIdentity(
            sessionId: options.sessionId ?? session.sessionId,
            referenceId: options.referenceId,
            subjectRef: options.subjectRef,
            email: options.email,
            mobile: options.mobile,
            fullName: options.fullName,
            dateOfBirth: dob,
            guardian: options.guardian,
            language: LanguageStore.normalize(options.language ?? LanguageStore.current)
        )

        let emailDisplay = identity.email ?? ""
        let mobileDisplay = identity.mobile ?? ""
        let nameDisplay = identity.fullName ?? ""
        let noticeLabel = resolvedToken != nil ? "linkToken: \(resolvedToken!.prefix(12))..." : "noticeCode: \(options.noticeCode ?? "")"
        SammatiLogger.debug("🚀 captureConsent started for \(noticeLabel), email: \(emailDisplay), mobile: \(mobileDisplay), fullName: \(nameDisplay)")

        let storeKey = options.noticeCode ?? resolvedToken ?? "consent"

        if isMinor {
            return try await MinorConsentFlow(api: APIClient(configuration: config))
                .run(noticeCode: options.noticeCode ?? resolvedToken ?? "", identity: identity, presenter: presenter)
        }

        if !options.forceDisplay && options.skipIfValid {
            let codes = !options.purposeCodes.isEmpty ? options.purposeCodes :
                (options.purposeCode.map { [$0] } ?? [])
            if !codes.isEmpty {
                var validations: [ConsentValidation] = []
                for code in codes {
                    let v = try await validate(identity: identity, purposeCode: code, noticeCode: options.noticeCode)
                    validations.append(v)
                    if !v.allowed { break }
                }
                if validations.allSatisfy({ $0.allowed }) {
                    GrantedConsentStore.record(noticeCode: storeKey, identity: identity)
                    return ConsentResult(
                        allMandatoryGranted: true,
                        status: "valid",
                        showNotice: false,
                        skipped: true,
                        message: "Consent has already been provided for all requested purposes."
                    )
                }
            }
        }

        let api = APIClient(configuration: config)
        let notice: Notice

        if let token = resolvedToken {
            SammatiLogger.info("🔗 Validating Public Consent Link via /api/v1/public/consent/link/...")
            notice = try await api.validateConsentLink(
                token: token,
                mobile: identity.mobile,
                email: identity.email
            )
        } else {
            let code = options.noticeCode ?? ""
            notice = try await api.fetchPublishedNotice(
                noticeCode: code,
                identity: identity,
                mobile: identity.mobile
            )
        }

        let shouldShowNotice = notice.showNotice ?? true

        SammatiLogger.info("📊 Consent Evaluation: showNotice=\(notice.showNotice ?? true), purposesCount=\(notice.purposes.count), shouldShowNotice=\(shouldShowNotice)")

        if !options.forceDisplay && !shouldShowNotice {
            GrantedConsentStore.record(noticeCode: storeKey, identity: identity)
            SammatiLogger.info("⚡ API returned show_notice=false. Consent already granted. Skipping UI.")
            return ConsentResult(
                allMandatoryGranted: true,
                status: "valid",
                showNotice: false,
                skipped: true,
                message: notice.message ?? "Consent has already been provided for all requested purposes."
            )
        }

        guard let presenter else {
            throw SammatiSDKError.serverError("A presenting UIViewController is required to display the consent notice.")
        }

        let baseTheme = NoticeTheme()
        let withConfig = configuration?.theme?.merged(with: baseTheme) ?? baseTheme
        let withNotice = notice.theme?.merged(with: withConfig) ?? withConfig
        let activeTheme = options.theme?.merged(with: withNotice) ?? withNotice

        let modalTitle = notice.noticeCode ?? options.noticeCode ?? "Notice"
        SammatiLogger.info("📱 Presenting Consent UI modal for notice: \(modalTitle)")
        let selection = try await ConsentViewController.present(notice: notice, theme: activeTheme, presenter: presenter)
        if selection.cancelled {
            SammatiLogger.warn("User cancelled / dismissed consent notice.")
            throw SammatiSDKError.cancelled
        }

        let result: SubmitResponse
        if let token = resolvedToken ?? notice.linkToken {
            SammatiLogger.info("Submitting user consent choices via Public Consent Link...")
            result = try await api.submitConsentLink(
                token: token,
                notice: notice,
                choices: selection.choices,
                identity: identity,
                language: selection.language
            )
        } else {
            SammatiLogger.debug("Submitting user consent choices (\(selection.choices.count) choices)...")
            result = try await api.submit(
                notice: notice,
                choices: selection.choices,
                identity: identity,
                language: selection.language
            )
        }

        let mapped = api.mapResult(result)

        if mapped.allMandatoryGranted {
            GrantedConsentStore.record(noticeCode: storeKey, identity: identity)
            SammatiLogger.info("Recorded granted consent in GrantedConsentStore.")
        }
        let statusDisplay = mapped.status ?? "unknown"
        let artifactDisplay = mapped.artifactId ?? "none"
        SammatiLogger.info("✅ Consent capture completed: status=\(statusDisplay), allMandatoryGranted=\(mapped.allMandatoryGranted), artifactId=\(artifactDisplay)")

        if mapped.linkRequired {
            PendingLinkStore.save(result: mapped)
        }

        if let reference = options.referenceId, !reference.isEmpty {
            _ = try await link(mapped: mapped, referenceId: reference)
        }

        return mapped
    }

    private func validatedConfiguration() throws -> SammatiConfiguration {
        guard let config = configuration else { throw SammatiSDKError.notConfigured }
        guard !config.clientId.isEmpty else {
            throw SammatiSDKError.invalidConfiguration("clientId cannot be empty.")
        }
        guard !config.origin.isEmpty else {
            throw SammatiSDKError.invalidConfiguration("origin cannot be empty.")
        }
        return config
    }

    private func validate(identity: ConsentIdentity, purposeCode: String, noticeCode: String?) async throws -> ConsentValidation {
        let config = try validatedConfiguration()
        let api = APIClient(configuration: config)
        return try await api.validate(identity: identity, purposeCode: purposeCode, noticeCode: noticeCode)
    }

    private func resume(referenceId: String) async throws -> ConsentResult {
        let config = try validatedConfiguration()
        guard let pending = PendingLinkStore.load() else { throw SammatiSDKError.noPendingConsent }
        if let expiry = pending.linkExpiresAt, expiry < Date() {
            PendingLinkStore.clear()
            throw SammatiSDKError.consentLinkExpired
        }
        let api = APIClient(configuration: config)
        try await api.linkReference(artifactId: pending.artifactId, preferenceToken: pending.preferenceToken, referenceId: referenceId)
        PendingLinkStore.clear()
        return ConsentResult(
            artifactId: pending.artifactId,
            allMandatoryGranted: true,
            preferenceToken: pending.preferenceToken,
            status: "linked",
            linkRequired: false
        )
    }

    private func link(mapped: ConsentResult, referenceId: String) async throws -> ConsentResult {
        let config = try validatedConfiguration()
        let api = APIClient(configuration: config)
        try await api.linkReference(artifactId: mapped.artifactId, preferenceToken: mapped.preferenceToken, referenceId: referenceId)
        PendingLinkStore.clear()
        return ConsentResult(
            artifactId: mapped.artifactId,
            subjectId: mapped.subjectId,
            allMandatoryGranted: mapped.allMandatoryGranted,
            preferenceToken: mapped.preferenceToken,
            status: mapped.status,
            linkRequired: false,
            linkExpiresAt: mapped.linkExpiresAt,
            dpType: mapped.dpType,
            minorConsentProfileId: mapped.minorConsentProfileId,
            minorDpId: mapped.minorDpId,
            invitationStatus: mapped.invitationStatus,
            invitationLink: mapped.invitationLink,
            guardianVerificationMode: mapped.guardianVerificationMode,
            guardianSessionToken: mapped.guardianSessionToken,
            guardianFrameUrl: mapped.guardianFrameUrl,
            guardianVerificationPending: mapped.guardianVerificationPending,
            realtimeStatus: mapped.realtimeStatus,
            showNotice: mapped.showNotice,
            skipped: mapped.skipped,
            cancelled: mapped.cancelled,
            message: mapped.message
        )
    }
}
