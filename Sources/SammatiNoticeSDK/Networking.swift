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

    private func requestRawData(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
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

        // Detailed request logging
        SammatiLogger.logRequest(
            url: url,
            method: method,
            headers: request.allHTTPHeaderFields ?? [:],
            body: body
        )

        let startTime = CFAbsoluteTimeGetCurrent()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let durationMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            SammatiLogger.error("❌ Network request failed: [\(method)] \(url.absoluteString) after \(String(format: "%.1f", durationMs)) ms with error: \(error.localizedDescription)")
            throw error
        }
        let durationMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        guard let http = response as? HTTPURLResponse else {
            SammatiLogger.error("❌ Non-HTTP response received from \(url.absoluteString)")
            throw SammatiSDKError.invalidResponse
        }

        // Detailed response logging
        SammatiLogger.logResponse(
            url: url,
            method: method,
            statusCode: http.statusCode,
            data: data,
            durationMs: durationMs
        )

        if !(200..<300).contains(http.statusCode) {
            let envelope = try? decoder.decode(APIEnvelope<EmptyResponse>.self, from: data)
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
            SammatiLogger.error("❌ API Error (HTTP \(http.statusCode)): \(errMsg)")
            throw SammatiSDKError.serverError(errMsg)
        }

        return data
    }

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        let data = try await requestRawData(path: path, method: method, body: body)
        let envelope = try? decoder.decode(APIEnvelope<T>.self, from: data)
        if let envelope {
            if var notice = envelope.data as? Notice {
                let resolvedShow = envelope.showNotice ?? notice.showNotice
                let resolvedMsg = envelope.message ?? notice.message
                notice = notice.withShowNotice(resolvedShow, message: resolvedMsg)
                if let typed = notice as? T {
                    return typed
                }
            } else if T.self == Notice.self {
                let emptyNotice = Notice().withShowNotice(envelope.showNotice, message: envelope.message)
                if let typed = emptyNotice as? T {
                    return typed
                }
            }
            if let payload = envelope.data {
                return payload
            }
        }
        if let direct = try? decoder.decode(T.self, from: data) {
            return direct
        }
        throw SammatiSDKError.invalidResponse
    }

    func parsePublishedNotice(from data: Data) throws -> Notice {
        let rawJson = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let showKeys = [
            "show_notice", "showNotice", "shownotice", "show_Notice",
            "is_show_notice", "isShowNotice", "is_notice_required",
            "notice_required", "show", "show_ui"
        ]

        func extractBool(from dict: [String: Any]?) -> Bool? {
            guard let dict else { return nil }
            for key in showKeys {
                if let val = dict[key] {
                    if let b = val as? Bool { return b }
                    if let s = val as? String {
                        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        if trimmed == "false" || trimmed == "0" || trimmed == "no" { return false }
                        if trimmed == "true" || trimmed == "1" || trimmed == "yes" { return true }
                    }
                    if let num = val as? NSNumber {
                        return num.boolValue
                    }
                }
            }
            return nil
        }

        var rawShowNotice = extractBool(from: rawJson)
        let dataDict = rawJson?["data"] as? [String: Any]
        if rawShowNotice == nil {
            rawShowNotice = extractBool(from: dataDict)
        }
        let noticeDict = dataDict?["notice"] as? [String: Any]
        if rawShowNotice == nil {
            rawShowNotice = extractBool(from: noticeDict)
        }

        var noticeData = data
        if let noticeDict, let nestedData = try? JSONSerialization.data(withJSONObject: noticeDict) {
            noticeData = nestedData
        }

        let envelope = try? decoder.decode(APIEnvelope<Notice>.self, from: data)
        var notice = envelope?.data ?? (try? decoder.decode(Notice.self, from: noticeData)) ?? (try? decoder.decode(Notice.self, from: data)) ?? Notice()

        let resolvedShow = rawShowNotice ?? envelope?.showNotice ?? notice.showNotice
        let resolvedMessage = (noticeDict?["message"] as? String) ?? envelope?.message ?? notice.message

        SammatiLogger.debug("📋 Parsed Published Notice: noticeCode=\(notice.noticeCode ?? "nil"), showNotice=\(String(describing: resolvedShow)) (raw=\(String(describing: rawShowNotice)), envelope=\(String(describing: envelope?.showNotice))), purposes=\(notice.purposes.count), message=\(resolvedMessage ?? "nil")")

        return notice.withShowNotice(resolvedShow, message: resolvedMessage)
    }

    private struct LinkValidatePayload: Encodable {
        let mobile: String?
        let email: String?
    }

    func validateConsentLink(
        token: String,
        mobile: String? = nil,
        email: String? = nil
    ) async throws -> Notice {
        let safeToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = "/api/v1/public/consent/link/\(safeToken)"

        let rawMobile = mobile?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMobile: String?
        if let rawMobile, !rawMobile.isEmpty {
            let digitsOnly = rawMobile.filter(\.isNumber)
            cleanMobile = !digitsOnly.isEmpty ? digitsOnly : rawMobile
        } else {
            cleanMobile = nil
        }

        let cleanEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let bodyData: Data?
        if cleanMobile != nil || (cleanEmail != nil && !cleanEmail!.isEmpty) {
            let payload = LinkValidatePayload(mobile: cleanMobile, email: cleanEmail)
            bodyData = try? encoder.encode(payload)
        } else {
            bodyData = nil
        }

        let method = bodyData != nil ? "POST" : "GET"
        let data = try await requestRawData(path: path, method: method, body: bodyData)
        var notice = try parsePublishedNotice(from: data)
        notice.linkToken = safeToken
        return notice
    }

    func submitConsentLink(
        token: String,
        notice: Notice,
        choices: [ConsentChoice],
        identity: ConsentIdentity,
        language: String
    ) async throws -> SubmitResponse {
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
        let safeToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await request(path: "/api/v1/public/consent/link/\(safeToken)/submit", method: "POST", body: data)
    }

    func fetchPublishedNotice(
        noticeCode: String,
        identity: ConsentIdentity? = nil,
        mobile: String? = nil
    ) async throws -> Notice {
        let safeChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~"))
        let safeNoticeCode = noticeCode.addingPercentEncoding(withAllowedCharacters: safeChars) ?? noticeCode
        let basePath = "/api/v1/public/consent/notices/\(safeNoticeCode)/published"

        var queryItems: [URLQueryItem] = []
        let rawMobile = (identity?.mobile ?? mobile)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rawMobile, !rawMobile.isEmpty {
            let digitsOnly = rawMobile.filter(\.isNumber)
            let mobileToSend = !digitsOnly.isEmpty ? digitsOnly : rawMobile
            queryItems.append(URLQueryItem(name: "mobile", value: mobileToSend))
        }
        if let email = identity?.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !email.isEmpty {
            queryItems.append(URLQueryItem(name: "email", value: email))
        }
        if let ref = identity?.referenceId?.trimmingCharacters(in: .whitespacesAndNewlines), !ref.isEmpty {
            queryItems.append(URLQueryItem(name: "reference_id", value: ref))
        }
        if let sub = identity?.subjectRef?.trimmingCharacters(in: .whitespacesAndNewlines), !sub.isEmpty {
            queryItems.append(URLQueryItem(name: "subject_ref", value: sub))
        }
        let sess = identity?.sessionId.trimmingCharacters(in: .whitespacesAndNewlines)
        if let sess, !sess.isEmpty {
            queryItems.append(URLQueryItem(name: "session_id", value: sess))
        }

        let fullPath: String
        if !queryItems.isEmpty {
            var components = URLComponents()
            components.queryItems = queryItems
            let queryString = components.percentEncodedQuery ?? ""
            fullPath = queryString.isEmpty ? basePath : "\(basePath)?\(queryString)"
        } else {
            fullPath = basePath
        }

        let data = try await requestRawData(path: fullPath)
        return try parsePublishedNotice(from: data)
    }

    func validate(identity: ConsentIdentity, purposeCode: String, noticeCode: String?) async throws -> ConsentValidation {
        let req = ValidateRequest(
            purposeCode: purposeCode,
            noticeCode: noticeCode,
            referenceId: identity.referenceId,
            sessionId: identity.sessionId,
            email: identity.email,
            mobile: identity.mobile,
            subjectRef: identity.subjectRef
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
    let email: String?
    let mobile: String?
    let subjectRef: String?

    init(
        purposeCode: String,
        noticeCode: String? = nil,
        referenceId: String? = nil,
        sessionId: String,
        email: String? = nil,
        mobile: String? = nil,
        subjectRef: String? = nil
    ) {
        self.purposeCode = purposeCode
        self.noticeCode = noticeCode
        self.referenceId = referenceId
        self.sessionId = sessionId
        self.email = email
        self.mobile = mobile
        self.subjectRef = subjectRef
    }

    enum CodingKeys: String, CodingKey {
        case purposeCode = "purpose_code"
        case noticeCode = "notice_code"
        case referenceId = "reference_id"
        case sessionId = "session_id"
        case email
        case mobile
        case subjectRef = "subject_ref"
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
