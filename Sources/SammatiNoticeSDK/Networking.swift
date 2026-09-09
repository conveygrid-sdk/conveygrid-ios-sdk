import Foundation

final class APIClient {
    private let configuration: SammatiConfiguration
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let session: URLSession

    init(configuration: SammatiConfiguration) {
        self.configuration = configuration
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30.0
        sessionConfig.timeoutIntervalForResource = 60.0
        sessionConfig.tlsMinimumSupportedProtocolVersion = .TLSv12
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: sessionConfig)
    }

    private func sanitizeHeaderValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        let normalizedPath = path.hasPrefix("/api/v1") ? path : "/api/v1\(path)"
        let base = configuration.apiBaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)\(normalizedPath)") else {
            throw SammatiSDKError.invalidResponse
        }

        let isLocalhost = url.host == "localhost" || url.host == "127.0.0.1"
        guard url.scheme == "https" || (configuration.environment == .sandbox && isLocalhost) else {
            throw SammatiSDKError.serverError("Insecure HTTP connections are not allowed. Only HTTPS is supported.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let cleanClientId = sanitizeHeaderValue(configuration.clientId)
        request.setValue(cleanClientId, forHTTPHeaderField: "X-Application-Key")

        let cleanOrigin = sanitizeHeaderValue(configuration.origin)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !cleanOrigin.isEmpty {
            request.setValue(cleanOrigin, forHTTPHeaderField: "Origin")
            request.setValue("\(cleanOrigin)/", forHTTPHeaderField: "Referer")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SammatiSDKError.invalidResponse
        }

        let envelope = try? decoder.decode(APIEnvelope<T>.self, from: data)
        if !(200..<300).contains(http.statusCode) {
            let errorDetails = envelope?.errors?.compactMap { item -> String? in
                if let field = item.field, let msg = item.message {
                    return "\(field): \(msg)"
                }
                return item.message
            }.joined(separator: "; ")

            let errMsg: String
            if let errorDetails, !errorDetails.isEmpty {
                errMsg = "\(envelope?.message ?? "Error"): \(errorDetails)"
            } else {
                errMsg = envelope?.message ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            }
            throw SammatiSDKError.serverError(errMsg)
        }

        if let envelope, let payload = envelope.data {
            return payload
        }
        if let direct = try? decoder.decode(T.self, from: data) {
            return direct
        }
        throw SammatiSDKError.invalidResponse
    }

    func fetchPublishedNotice(noticeCode: String, mobile: String? = nil) async throws -> Notice {
        let safeChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~"))
        let safeNoticeCode = noticeCode.addingPercentEncoding(withAllowedCharacters: safeChars) ?? noticeCode
        let path = "/api/v1/public/consent/notices/\(safeNoticeCode)/published"
        if let mobile, !mobile.isEmpty {
            let encodedMobile = mobile.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? mobile
            let mobileNotice: Notice = try await request(path: "\(path)?mobile=\(encodedMobile)")
            if mobileNotice.showNotice == false {
                let baseNotice: Notice = try await request(path: path)
                let show = mobileNotice.showNotice ?? baseNotice.showNotice
                if show == false {
                    return Notice(
                        noticeId: baseNotice.noticeId,
                        noticeCode: baseNotice.noticeCode,
                        version: baseNotice.version,
                        noticeName: baseNotice.noticeName,
                        introductionText: baseNotice.introductionText,
                        footerText: baseNotice.footerText,
                        rightsText: baseNotice.rightsText,
                        contactInformation: baseNotice.contactInformation,
                        showNotice: mobileNotice.showNotice,
                        supportsMinors: baseNotice.supportsMinors,
                        guardianVerificationMode: baseNotice.guardianVerificationMode,
                        theme: baseNotice.theme,
                        message: mobileNotice.message,
                        purposes: baseNotice.purposes
                    )
                }
            }
            return mobileNotice
        }
        return try await request(path: path)
    }

    func validate(identity: ConsentIdentity, purposeCode: String, noticeCode: String?) async throws -> ConsentValidation {
        let req = ValidateRequest(
            purposeCode: purposeCode,
            noticeCode: noticeCode,
            referenceId: identity.referenceId,
            sessionId: identity.sessionId
        )
        let data = try encoder.encode(req)
        return try await request(path: "/api/v1/public/consent/validate", method: "POST", body: data)
    }

    func submit(notice: Notice, choices: [ConsentChoice], identity: ConsentIdentity, language: String) async throws -> SubmitResponse {
        let subject: SubmitSubject? = identity.subjectRef != nil ? nil : SubmitSubject(
            sessionId: identity.sessionId,
            referenceId: identity.referenceId,
            email: identity.email,
            mobile: identity.mobile,
            fullName: identity.fullName
        )

        let dp: SubmitDataPrincipal?
        if let dob = identity.dateOfBirth?.trimmingCharacters(in: .whitespacesAndNewlines), !dob.isEmpty {
            dp = SubmitDataPrincipal(
                dateOfBirth: dob,
                fullName: identity.fullName?.isEmpty == false ? identity.fullName : nil,
                email: identity.email?.isEmpty == false ? identity.email?.lowercased() : nil,
                mobile: identity.mobile?.isEmpty == false ? identity.mobile?.filter(\.isNumber) : nil,
                preferredLanguage: language
            )
        } else {
            dp = nil
        }

        let guardian: SubmitGuardian?
        if let g = identity.guardian {
            guardian = SubmitGuardian(
                guardianName: g.guardianName,
                guardianEmail: g.guardianEmail?.lowercased(),
                guardianMobile: g.guardianMobile?.filter(\.isNumber),
                relationshipCode: g.relationshipCode?.uppercased(),
                relationshipId: g.relationshipId
            )
        } else {
            guardian = nil
        }

        let submitChoices = choices.map { SubmitChoice(purposeId: $0.purposeId, granted: $0.granted) }

        let req = SubmitRequest(
            noticeId: notice.noticeId,
            version: notice.version,
            choices: submitChoices,
            language: language,
            pageUrl: nil,
            subject: subject,
            subjectRef: identity.subjectRef,
            dataPrincipal: dp,
            guardian: guardian
        )

        let data = try encoder.encode(req)
        return try await request(path: "/api/v1/public/consent/notices/submit", method: "POST", body: data)
    }

    func linkReference(artifactId: String?, preferenceToken: String?, referenceId: String) async throws {
        guard artifactId != nil || preferenceToken != nil else {
            throw SammatiSDKError.invalidResponse
        }
        let req = LinkReferenceRequest(referenceId: referenceId, artifactId: artifactId, preferenceToken: preferenceToken)
        let data = try encoder.encode(req)
        let _: EmptyResponse = try await request(path: "/api/v1/public/consent/artifacts/link-reference", method: "POST", body: data)
    }

    func mapResult(_ r: SubmitResponse) -> ConsentResult {
        ConsentResult(
            artifactId: r.artifactId,
            subjectId: r.subjectId,
            allMandatoryGranted: r.allMandatoryGranted ?? false,
            preferenceToken: r.preferenceToken,
            status: r.status,
            linkRequired: r.linkRequired ?? false,
            linkExpiresAt: DateParser.parse(r.linkExpiresAt),
            dpType: r.dpType,
            minorConsentProfileId: r.minorConsentProfileId,
            minorDpId: r.minorDpId,
            invitationStatus: r.invitationStatus,
            invitationLink: r.invitationLink,
            guardianVerificationMode: r.guardianVerificationMode ?? "INVITATION_LINK",
            guardianSessionToken: r.guardianSessionToken,
            guardianFrameUrl: r.guardianFrameUrl,
            guardianVerificationPending: r.status == "guardian_verification_pending"
        )
    }
}

struct EmptyResponse: Decodable, Sendable {}

struct ValidateRequest: Encodable {
    let purposeCode: String
    let noticeCode: String?
    let referenceId: String?
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case purposeCode = "purpose_code"
        case noticeCode = "notice_code"
        case referenceId = "reference_id"
        case sessionId = "session_id"
    }
}

struct SubmitRequest: Encodable {
    let noticeId: String?
    let version: String?
    let choices: [SubmitChoice]
    let language: String
    let pageUrl: String?
    let subject: SubmitSubject?
    let subjectRef: String?
    let dataPrincipal: SubmitDataPrincipal?
    let guardian: SubmitGuardian?

    enum CodingKeys: String, CodingKey {
        case noticeId = "notice_id"
        case version
        case choices
        case language
        case pageUrl = "page_url"
        case subject
        case subjectRef = "subject_ref"
        case dataPrincipal
        case guardian
    }
}

struct SubmitChoice: Encodable {
    let purposeId: String
    let granted: Bool

    enum CodingKeys: String, CodingKey {
        case purposeId = "purpose_id"
        case granted
    }
}

struct SubmitSubject: Encodable {
    let sessionId: String
    let referenceId: String?
    let email: String?
    let mobile: String?
    let fullName: String?
}

struct SubmitDataPrincipal: Encodable {
    let dateOfBirth: String
    let fullName: String?
    let email: String?
    let mobile: String?
    let preferredLanguage: String
}

struct SubmitGuardian: Encodable {
    let guardianName: String
    let guardianEmail: String?
    let guardianMobile: String?
    let relationshipCode: String?
    let relationshipId: String?
}

struct LinkReferenceRequest: Encodable {
    let referenceId: String
    let artifactId: String?
    let preferenceToken: String?
}
