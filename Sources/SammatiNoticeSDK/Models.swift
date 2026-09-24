import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct ConsentIdentity: Codable, Sendable {
    public let sessionId: String
    public let referenceId: String?
    public let subjectRef: String?
    public let email: String?
    public let mobile: String?
    public let fullName: String?
    public let dateOfBirth: String?
    public let guardian: Guardian?
    public let language: String

    public init(
        sessionId: String,
        referenceId: String? = nil,
        subjectRef: String? = nil,
        email: String? = nil,
        mobile: String? = nil,
        fullName: String? = nil,
        dateOfBirth: String? = nil,
        guardian: Guardian? = nil,
        language: String = "en"
    ) {
        self.sessionId = sessionId
        self.referenceId = referenceId
        self.subjectRef = subjectRef
        self.email = email
        self.mobile = mobile
        self.fullName = fullName
        self.dateOfBirth = dateOfBirth
        self.guardian = guardian
        self.language = language
    }
}

public struct ConsentValidation: Codable, Sendable {
    public let allowed: Bool
    public let message: String?
    public let status: String?

    public init(allowed: Bool, message: String? = nil, status: String? = nil) {
        self.allowed = allowed
        self.message = message
        self.status = status
    }
}

struct Notice: Codable, Sendable {
    let noticeId: String?
    let noticeCode: String?
    let version: String?
    let noticeName: String?
    let introductionText: String?
    let footerText: String?
    let rightsText: String?
    let contactInformation: String?
    let showNotice: Bool?
    let supportsMinors: Bool?
    let guardianVerificationMode: String?
    let theme: NoticeTheme?
    let message: String?
    let purposes: [Purpose]
    var linkToken: String?

    enum CodingKeys: String, CodingKey {
        case noticeId = "notice_id"
        case noticeIdCamel = "noticeId"
        case noticeCode = "notice_code"
        case noticeCodeCamel = "noticeCode"
        case version
        case noticeName = "notice_name"
        case noticeNameCamel = "noticeName"
        case introductionText = "introduction_text"
        case introductionTextCamel = "introductionText"
        case footerText = "footer_text"
        case footerTextCamel = "footerText"
        case rightsText = "rights_text"
        case rightsTextCamel = "rightsText"
        case contactInformation = "contact_information"
        case contactInformationCamel = "contactInformation"
        case showNotice = "show_notice"
        case showNoticeCamel = "showNotice"
        case showNoticeLower = "shownotice"
        case showNoticeSnakeUpper = "show_Notice"
        case isNoticeRequired = "is_notice_required"
        case noticeRequired = "notice_required"
        case supportsMinors = "supports_minors"
        case supportsMinorsCamel = "supportsMinors"
        case guardianVerificationMode = "guardian_verification_mode"
        case guardianVerificationModeCamel = "guardianVerificationMode"
        case theme
        case purposes
        case message
    }

    init(
        noticeId: String? = nil,
        noticeCode: String? = nil,
        version: String? = nil,
        noticeName: String? = nil,
        introductionText: String? = nil,
        footerText: String? = nil,
        rightsText: String? = nil,
        contactInformation: String? = nil,
        showNotice: Bool? = nil,
        supportsMinors: Bool? = nil,
        guardianVerificationMode: String? = nil,
        theme: NoticeTheme? = nil,
        message: String? = nil,
        purposes: [Purpose] = [],
        linkToken: String? = nil
    ) {
        self.noticeId = noticeId
        self.noticeCode = noticeCode
        self.version = version
        self.noticeName = noticeName
        self.introductionText = introductionText
        self.footerText = footerText
        self.rightsText = rightsText
        self.contactInformation = contactInformation
        self.showNotice = showNotice
        self.supportsMinors = supportsMinors
        self.guardianVerificationMode = guardianVerificationMode
        self.theme = theme
        self.message = message
        self.purposes = purposes
        self.linkToken = linkToken
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        noticeId = (try? container.decodeIfPresent(String.self, forKey: .noticeId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .noticeIdCamel))
        noticeCode = (try? container.decodeIfPresent(String.self, forKey: .noticeCode))
            ?? (try? container.decodeIfPresent(String.self, forKey: .noticeCodeCamel))
        version = try? container.decodeIfPresent(String.self, forKey: .version)
        noticeName = (try? container.decodeIfPresent(String.self, forKey: .noticeName))
            ?? (try? container.decodeIfPresent(String.self, forKey: .noticeNameCamel))
        introductionText = (try? container.decodeIfPresent(String.self, forKey: .introductionText))
            ?? (try? container.decodeIfPresent(String.self, forKey: .introductionTextCamel))
        footerText = (try? container.decodeIfPresent(String.self, forKey: .footerText))
            ?? (try? container.decodeIfPresent(String.self, forKey: .footerTextCamel))
        rightsText = (try? container.decodeIfPresent(String.self, forKey: .rightsText))
            ?? (try? container.decodeIfPresent(String.self, forKey: .rightsTextCamel))
        contactInformation = (try? container.decodeIfPresent(String.self, forKey: .contactInformation))
            ?? (try? container.decodeIfPresent(String.self, forKey: .contactInformationCamel))
        showNotice = container.decodeFlexibleBool(forKeys: [
            .showNotice,
            .showNoticeCamel,
            .showNoticeLower,
            .showNoticeSnakeUpper,
            .isNoticeRequired,
            .noticeRequired
        ])
        supportsMinors = container.decodeFlexibleBool(forKeys: [.supportsMinors, .supportsMinorsCamel])
        guardianVerificationMode = (try? container.decodeIfPresent(String.self, forKey: .guardianVerificationMode))
            ?? (try? container.decodeIfPresent(String.self, forKey: .guardianVerificationModeCamel))
        theme = try? container.decodeIfPresent(NoticeTheme.self, forKey: .theme)
        message = try? container.decodeIfPresent(String.self, forKey: .message)
        purposes = (try? container.decodeIfPresent([Purpose].self, forKey: .purposes)) ?? []
        linkToken = nil
    }

    func withShowNotice(_ show: Bool?, message: String? = nil) -> Notice {
        Notice(
            noticeId: self.noticeId,
            noticeCode: self.noticeCode,
            version: self.version,
            noticeName: self.noticeName,
            introductionText: self.introductionText,
            footerText: self.footerText,
            rightsText: self.rightsText,
            contactInformation: self.contactInformation,
            showNotice: show ?? self.showNotice,
            supportsMinors: self.supportsMinors,
            guardianVerificationMode: self.guardianVerificationMode,
            theme: self.theme,
            message: message ?? self.message,
            purposes: self.purposes,
            linkToken: self.linkToken
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(noticeId, forKey: .noticeId)
        try container.encodeIfPresent(noticeCode, forKey: .noticeCode)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encodeIfPresent(noticeName, forKey: .noticeName)
        try container.encodeIfPresent(introductionText, forKey: .introductionText)
        try container.encodeIfPresent(footerText, forKey: .footerText)
        try container.encodeIfPresent(rightsText, forKey: .rightsText)
        try container.encodeIfPresent(contactInformation, forKey: .contactInformation)
        try container.encodeIfPresent(showNotice, forKey: .showNotice)
        try container.encodeIfPresent(supportsMinors, forKey: .supportsMinors)
        try container.encodeIfPresent(guardianVerificationMode, forKey: .guardianVerificationMode)
        try container.encodeIfPresent(theme, forKey: .theme)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encode(purposes, forKey: .purposes)
    }
}

public struct NoticeTheme: Codable, Sendable {
    public let themeId: String?
    public let themeName: String?
    public let primaryColor: String?
    public let secondaryColor: String?
    public let fontFamily: String?
    public let logoURL: String?
    public let preferredMode: String?

    public init(
        themeId: String? = nil,
        themeName: String? = nil,
        primaryColor: String? = nil,
        secondaryColor: String? = nil,
        fontFamily: String? = nil,
        logoURL: String? = nil,
        preferredMode: String? = nil
    ) {
        self.themeId = themeId
        self.themeName = themeName
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.fontFamily = fontFamily
        self.logoURL = logoURL
        self.preferredMode = preferredMode
    }

#if canImport(UIKit)
    public init(
        themeId: String? = nil,
        themeName: String? = nil,
        primaryColor: String? = nil,
        secondaryColor: String? = nil,
        fontFamily: String? = nil,
        logoURL: String? = nil,
        interfaceStyle: UIUserInterfaceStyle
    ) {
        let modeString: String
        switch interfaceStyle {
        case .light: modeString = "light"
        case .dark: modeString = "dark"
        default: modeString = "system"
        }
        self.init(
            themeId: themeId,
            themeName: themeName,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            fontFamily: fontFamily,
            logoURL: logoURL,
            preferredMode: modeString
        )
    }

    public var interfaceStyle: UIUserInterfaceStyle {
        switch preferredMode?.lowercased() {
        case "light": return .light
        case "dark": return .dark
        default: return .unspecified
        }
    }
#endif

    enum CodingKeys: String, CodingKey {
        case themeId = "theme_id"
        case themeName = "theme_name"
        case primaryColor = "primary_color"
        case secondaryColor = "secondary_color"
        case fontFamily = "font_family"
        case logoURL = "logo_url"
        case preferredMode = "preferred_mode"
    }

    public func merged(with fallback: NoticeTheme?) -> NoticeTheme {
        guard let fallback = fallback else { return self }
        return NoticeTheme(
            themeId: self.themeId ?? fallback.themeId,
            themeName: self.themeName ?? fallback.themeName,
            primaryColor: self.primaryColor ?? fallback.primaryColor,
            secondaryColor: self.secondaryColor ?? fallback.secondaryColor,
            fontFamily: self.fontFamily ?? fallback.fontFamily,
            logoURL: self.logoURL ?? fallback.logoURL,
            preferredMode: self.preferredMode ?? fallback.preferredMode
        )
    }
}

struct Purpose: Codable, Sendable {
    let purposeId: String?
    let purposeCode: String?
    let purposeName: String?
    let purposeDescription: String?
    let isMandatory: Bool?
    let purposeIsMandatory: Bool?
    let alreadyGranted: Bool?
    let displayOrder: Int?
    let categories: [PurposeCategory]

    enum CodingKeys: String, CodingKey {
        case purposeId = "purpose_id"
        case purposeIdCamel = "purposeId"
        case purposeCode = "purpose_code"
        case purposeCodeCamel = "purposeCode"
        case purposeName = "purpose_name"
        case purposeNameCamel = "purposeName"
        case purposeDescription = "purpose_description"
        case purposeDescriptionCamel = "purposeDescription"
        case isMandatory = "is_mandatory"
        case isMandatoryCamel = "isMandatory"
        case purposeIsMandatory = "purpose_is_mandatory"
        case alreadyGranted = "already_granted"
        case alreadyGrantedCamel = "alreadyGranted"
        case alreadyGrantedLower = "alreadygranted"
        case isGranted = "is_granted"
        case isGrantedCamel = "isGranted"
        case isGrantedLower = "isgranted"
        case granted
        case consented
        case isConsented = "is_consented"
        case displayOrder = "display_order"
        case displayOrderCamel = "displayOrder"
        case categories
    }

    init(
        purposeId: String? = nil,
        purposeCode: String? = nil,
        purposeName: String? = nil,
        purposeDescription: String? = nil,
        isMandatory: Bool? = nil,
        purposeIsMandatory: Bool? = nil,
        alreadyGranted: Bool? = nil,
        displayOrder: Int? = nil,
        categories: [PurposeCategory] = []
    ) {
        self.purposeId = purposeId
        self.purposeCode = purposeCode
        self.purposeName = purposeName
        self.purposeDescription = purposeDescription
        self.isMandatory = isMandatory
        self.purposeIsMandatory = purposeIsMandatory
        self.alreadyGranted = alreadyGranted
        self.displayOrder = displayOrder
        self.categories = categories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        purposeId = (try? container.decodeIfPresent(String.self, forKey: .purposeId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .purposeIdCamel))
        purposeCode = (try? container.decodeIfPresent(String.self, forKey: .purposeCode))
            ?? (try? container.decodeIfPresent(String.self, forKey: .purposeCodeCamel))
        purposeName = (try? container.decodeIfPresent(String.self, forKey: .purposeName))
            ?? (try? container.decodeIfPresent(String.self, forKey: .purposeNameCamel))
        purposeDescription = (try? container.decodeIfPresent(String.self, forKey: .purposeDescription))
            ?? (try? container.decodeIfPresent(String.self, forKey: .purposeDescriptionCamel))
        isMandatory = container.decodeFlexibleBool(forKeys: [.isMandatory, .isMandatoryCamel, .purposeIsMandatory])
        purposeIsMandatory = isMandatory
        alreadyGranted = container.decodeFlexibleBool(forKeys: [
            .alreadyGranted,
            .alreadyGrantedCamel,
            .alreadyGrantedLower,
            .isGranted,
            .isGrantedCamel,
            .isGrantedLower,
            .granted,
            .consented,
            .isConsented
        ])
        displayOrder = (try? container.decodeIfPresent(Int.self, forKey: .displayOrder))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .displayOrderCamel))
        categories = (try? container.decodeIfPresent([PurposeCategory].self, forKey: .categories)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(purposeId, forKey: .purposeId)
        try container.encodeIfPresent(purposeCode, forKey: .purposeCode)
        try container.encodeIfPresent(purposeName, forKey: .purposeName)
        try container.encodeIfPresent(purposeDescription, forKey: .purposeDescription)
        try container.encodeIfPresent(isMandatory, forKey: .isMandatory)
        try container.encodeIfPresent(alreadyGranted, forKey: .alreadyGranted)
        try container.encodeIfPresent(displayOrder, forKey: .displayOrder)
        try container.encode(categories, forKey: .categories)
    }

    var mandatory: Bool { isMandatory ?? purposeIsMandatory ?? false }
    var granted: Bool { alreadyGranted ?? false }
}

struct PurposeCategory: Codable, Sendable {
    let categoryId: String?
    let categoryCode: String?
    let categoryName: String?
    let displayOrder: Int?

    init(
        categoryId: String? = nil,
        categoryCode: String? = nil,
        categoryName: String? = nil,
        displayOrder: Int? = nil
    ) {
        self.categoryId = categoryId
        self.categoryCode = categoryCode
        self.categoryName = categoryName
        self.displayOrder = displayOrder
    }

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryCode = "category_code"
        case categoryName = "category_name"
        case displayOrder = "display_order"
    }
}

struct SubmitResponse: Codable, Sendable {
    let artifactId: String?
    let subjectId: String?
    let allMandatoryGranted: Bool?
    let preferenceToken: String?
    let status: String?
    let linkRequired: Bool?
    let linkExpiresAt: String?
    let dpType: String?
    let minorConsentProfileId: String?
    let minorDpId: String?
    let invitationStatus: String?
    let invitationLink: String?
    let guardianVerificationMode: String?
    let guardianSessionToken: String?
    let guardianFrameUrl: String?

    enum CodingKeys: String, CodingKey {
        case artifactId = "artifact_id"
        case subjectId = "subject_id"
        case allMandatoryGranted = "all_mandatory_granted"
        case preferenceToken = "preference_token"
        case status
        case linkRequired = "link_required"
        case linkExpiresAt = "link_expires_at"
        case dpType = "dp_type"
        case minorConsentProfileId = "minor_consent_profile_id"
        case minorDpId = "minor_dp_id"
        case invitationStatus = "invitation_status"
        case invitationLink = "invitation_link"
        case guardianVerificationMode = "guardian_verification_mode"
        case guardianSessionToken = "guardian_session_token"
        case guardianFrameUrl = "guardian_frame_url"
    }
}

struct APIErrorDetail: Decodable, Sendable {
    let code: String?
    let field: String?
    let message: String?
}

struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool?
    let data: T?
    let message: String?
    let showNotice: Bool?
    let errors: [APIErrorDetail]?

    enum CodingKeys: String, CodingKey {
        case success
        case data
        case message
        case showNotice = "show_notice"
        case showNoticeCamel = "showNotice"
        case showNoticeLower = "shownotice"
        case showNoticeSnakeUpper = "show_Notice"
        case isNoticeRequired = "is_notice_required"
        case noticeRequired = "notice_required"
        case errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try? container.decodeIfPresent(Bool.self, forKey: .success)
        data = try? container.decodeIfPresent(T.self, forKey: .data)
        message = try? container.decodeIfPresent(String.self, forKey: .message)
        showNotice = container.decodeFlexibleBool(forKeys: [
            .showNotice,
            .showNoticeCamel,
            .showNoticeLower,
            .showNoticeSnakeUpper,
            .isNoticeRequired,
            .noticeRequired
        ])
        errors = try? container.decodeIfPresent([APIErrorDetail].self, forKey: .errors)
    }
}
