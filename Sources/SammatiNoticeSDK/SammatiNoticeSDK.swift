import Foundation
import UIKit

public enum SammatiEnvironment {
    case sandbox
    case production
}

public struct SammatiConfiguration {
    public let clientId: String
    public let apiBaseURL: URL
    public let environment: SammatiEnvironment
    public let origin: String?

    public init(
        clientId: String,
        apiBaseURL: URL,
        environment: SammatiEnvironment = .production,
        origin: String? = nil
    ) {
        self.clientId = clientId
        self.apiBaseURL = apiBaseURL
        self.environment = environment
        self.origin = origin
    }
}

public enum SammatiSDKError: LocalizedError {
    case notConfigured
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
    public let noticeCode: String
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

    public init(
        noticeCode: String,
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
        skipIfValid: Bool = true
    ) {
        self.noticeCode = noticeCode
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
        guard configuration != nil else { throw SammatiSDKError.notConfigured }
        guard !options.noticeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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

        if isMinor {
            return try await MinorConsentFlow(api: APIClient(configuration: configuration!))
                .run(noticeCode: options.noticeCode, identity: identity, presenter: presenter)
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

        let api = APIClient(configuration: configuration!)
        let notice = try await api.fetchPublishedNotice(noticeCode: options.noticeCode, mobile: identity.mobile)
        if !options.forceDisplay && notice.showNotice == false {
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

        let selection = try await ConsentViewController.present(notice: notice, presenter: presenter)
        if selection.cancelled { throw SammatiSDKError.cancelled }

        let result = try await api.submit(notice: notice, choices: selection.choices, identity: identity, language: selection.language)
        let mapped = api.mapResult(result)

        if mapped.linkRequired {
            PendingLinkStore.save(result: mapped)
        }

        if let reference = options.referenceId, !reference.isEmpty {
            _ = try await link(mapped: mapped, referenceId: reference)
        }

        return mapped
    }

    private func validate(identity: ConsentIdentity, purposeCode: String, noticeCode: String?) async throws -> ConsentValidation {
        let api = APIClient(configuration: configuration!)
        return try await api.validate(identity: identity, purposeCode: purposeCode, noticeCode: noticeCode)
    }

    private func resume(referenceId: String) async throws -> ConsentResult {
        guard let pending = PendingLinkStore.load() else { throw SammatiSDKError.noPendingConsent }
        if let expiry = pending.linkExpiresAt, expiry < Date() {
            PendingLinkStore.clear()
            throw SammatiSDKError.consentLinkExpired
        }
        let api = APIClient(configuration: configuration!)
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
        let api = APIClient(configuration: configuration!)
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
