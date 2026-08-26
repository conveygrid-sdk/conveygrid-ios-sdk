import Foundation

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

    enum CodingKeys: String, CodingKey {
        case noticeId = "notice_id"
        case noticeCode = "notice_code"
        case version
        case noticeName = "notice_name"
        case introductionText = "introduction_text"
        case footerText = "footer_text"
        case rightsText = "rights_text"
        case contactInformation = "contact_information"
        case showNotice = "show_notice"
        case supportsMinors = "supports_minors"
        case guardianVerificationMode = "guardian_verification_mode"
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
        purposes: [Purpose] = []
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        noticeId = try container.decodeIfPresent(String.self, forKey: .noticeId)
        noticeCode = try container.decodeIfPresent(String.self, forKey: .noticeCode)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        noticeName = try container.decodeIfPresent(String.self, forKey: .noticeName)
        introductionText = try container.decodeIfPresent(String.self, forKey: .introductionText)
        footerText = try container.decodeIfPresent(String.self, forKey: .footerText)
        rightsText = try container.decodeIfPresent(String.self, forKey: .rightsText)
        contactInformation = try container.decodeIfPresent(String.self, forKey: .contactInformation)
        showNotice = try container.decodeIfPresent(Bool.self, forKey: .showNotice)
        supportsMinors = try container.decodeIfPresent(Bool.self, forKey: .supportsMinors)
        guardianVerificationMode = try container.decodeIfPresent(String.self, forKey: .guardianVerificationMode)
        theme = try container.decodeIfPresent(NoticeTheme.self, forKey: .theme)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        purposes = (try container.decodeIfPresent([Purpose].self, forKey: .purposes)) ?? []
    }
}

public struct NoticeTheme: Codable, Sendable {
    public let themeId: String?
    public let themeName: String?
    public let primaryColor: String?
    public let secondaryColor: String?
    public let fontFamily: String?
    public let logoURL: String?

    public init(
        themeId: String? = nil,
        themeName: String? = nil,
        primaryColor: String? = nil,
        secondaryColor: String? = nil,
        fontFamily: String? = nil,
        logoURL: String? = nil
    ) {
        self.themeId = themeId
        self.themeName = themeName
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.fontFamily = fontFamily
        self.logoURL = logoURL
    }

    enum CodingKeys: String, CodingKey {
        case themeId = "theme_id"
        case themeName = "theme_name"
        case primaryColor = "primary_color"
        case secondaryColor = "secondary_color"
        case fontFamily = "font_family"
        case logoURL = "logo_url"
    }

    public func merged(with fallback: NoticeTheme?) -> NoticeTheme {
        guard let fallback = fallback else { return self }
        return NoticeTheme(
            themeId: self.themeId ?? fallback.themeId,
            themeName: self.themeName ?? fallback.themeName,
            primaryColor: self.primaryColor ?? fallback.primaryColor,
            secondaryColor: self.secondaryColor ?? fallback.secondaryColor,
            fontFamily: self.fontFamily ?? fallback.fontFamily,
            logoURL: self.logoURL ?? fallback.logoURL
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
        case purposeCode = "purpose_code"
        case purposeName = "purpose_name"
        case purposeDescription = "purpose_description"
        case isMandatory = "is_mandatory"
        case purposeIsMandatory = "purpose_is_mandatory"
        case alreadyGranted = "already_granted"
        case displayOrder = "display_order"
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
        purposeId = try container.decodeIfPresent(String.self, forKey: .purposeId)
        purposeCode = try container.decodeIfPresent(String.self, forKey: .purposeCode)
        purposeName = try container.decodeIfPresent(String.self, forKey: .purposeName)
        purposeDescription = try container.decodeIfPresent(String.self, forKey: .purposeDescription)
        isMandatory = try container.decodeIfPresent(Bool.self, forKey: .isMandatory)
        purposeIsMandatory = try container.decodeIfPresent(Bool.self, forKey: .purposeIsMandatory)
        alreadyGranted = try container.decodeIfPresent(Bool.self, forKey: .alreadyGranted)
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder)
        categories = (try container.decodeIfPresent([PurposeCategory].self, forKey: .categories)) ?? []
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

struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool?
    let data: T?
    let message: String?
}
