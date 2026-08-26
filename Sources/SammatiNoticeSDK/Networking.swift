import Foundation

final class APIClient {
    private let configuration: SammatiConfiguration
    private let decoder = JSONDecoder()

    init(configuration: SammatiConfiguration) {
        self.configuration = configuration
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

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.clientId, forHTTPHeaderField: "X-Application-Key")
        if let origin = configuration.origin, !origin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let cleanOrigin = origin.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            request.setValue(cleanOrigin, forHTTPHeaderField: "Origin")
            request.setValue("\(cleanOrigin)/", forHTTPHeaderField: "Referer")
        }

        let bodyStr = body != nil ? (String(data: body!, encoding: .utf8) ?? "<binary data>") : "None"
        print("""
        ==================================================
        🌐 [SammatiNoticeSDK API Request]
        ➡️ Method: \(method)
        🔗 URL: \(url.absoluteString)
        📋 Headers:
        \(request.allHTTPHeaderFields?.map { "   • \($0.key): \($0.value)" }.joined(separator: "\n") ?? "")
        📦 Body: \(bodyStr)
        ==================================================
        """)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            print("❌ [SammatiNoticeSDK Network Error] Non-HTTP response returned.")
            throw SammatiSDKError.invalidResponse
        }

        let responseStr = String(data: data, encoding: .utf8) ?? "<non-text data>"
        print("""
        ==================================================
        📥 [SammatiNoticeSDK API Response]
        ⬅️ Status Code: \(http.statusCode)
        🔗 URL: \(url.absoluteString)
        📄 Response Body: \(responseStr)
        ==================================================
        """)

        let envelope = try? decoder.decode(APIEnvelope<T>.self, from: data)
        if !(200..<300).contains(http.statusCode) {
            throw SammatiSDKError.serverError(envelope?.message ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }

        if let envelope, envelope.success == true, let value = envelope.data {
            return value
        }

        if let direct = try? decoder.decode(T.self, from: data) {
            return direct
        }

        throw SammatiSDKError.serverError(envelope?.message ?? "Invalid API response.")
    }

    func fetchPublishedNotice(noticeCode: String, mobile: String?) async throws -> Notice {
        let path = "/api/v1/public/consent/notices/\(noticeCode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? noticeCode)/published"
        if let mobile, !mobile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let body = try JSONSerialization.data(withJSONObject: ["mobile": mobile])
            let mobileNotice: Notice = try await request(path: path, method: "POST", body: body)
            if mobileNotice.purposes.isEmpty || mobileNotice.noticeId == nil {
                if let baseNotice: Notice = try? await request(path: path, method: "GET") {
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
        var body: [String: Any] = [
            "purpose_code": purposeCode,
            "notice_code": noticeCode as Any,
            "reference_id": identity.referenceId as Any,
            "session_id": identity.sessionId
        ]
        body = body.compactMapValues { $0 is NSNull ? nil : $0 }
        let data = try JSONSerialization.data(withJSONObject: body)
        return try await request(path: "/api/v1/public/consent/validate", method: "POST", body: data)
    }

    func submit(notice: Notice, choices: [ConsentChoice], identity: ConsentIdentity, language: String) async throws -> SubmitResponse {
        var subject: [String: Any] = [
            "sessionId": identity.sessionId,
            "referenceId": identity.referenceId as Any,
            "email": identity.email as Any,
            "mobile": identity.mobile as Any
        ]
        if let fullName = identity.fullName { subject["fullName"] = fullName }
        subject = subject.compactMapValues { $0 is NSNull ? nil : $0 }

        var body: [String: Any] = [
            "notice_id": notice.noticeId as Any,
            "version": notice.version as Any,
            "choices": choices.map { ["purpose_id": $0.purposeId, "granted": $0.granted] },
            "language": language,
            "page_url": NSNull(),
            "subject": subject
        ]

        if let subjectRef = identity.subjectRef {
            body["subject_ref"] = subjectRef
            body.removeValue(forKey: "subject")
        }

        let dob = identity.dateOfBirth ?? "1990-01-01"
        var dp: [String: Any] = ["dateOfBirth": dob]
        if let name = identity.fullName, !name.isEmpty { dp["fullName"] = name }
        if let email = identity.email, !email.isEmpty { dp["email"] = email.lowercased() }
        if let mobile = identity.mobile, !mobile.isEmpty { dp["mobile"] = mobile.filter(\.isNumber) }
        dp["preferredLanguage"] = language
        body["dataPrincipal"] = dp

        if let guardian = identity.guardian {
            var g: [String: Any] = ["guardianName": guardian.guardianName]
            if let v = guardian.guardianEmail { g["guardianEmail"] = v.lowercased() }
            if let v = guardian.guardianMobile { g["guardianMobile"] = v.filter(\.isNumber) }
            if let v = guardian.relationshipCode { g["relationshipCode"] = v.uppercased() }
            if let v = guardian.relationshipId { g["relationshipId"] = v }
            body["guardian"] = g
        }

        let data = try JSONSerialization.data(withJSONObject: body)
        return try await request(path: "/api/v1/public/consent/notices/submit", method: "POST", body: data)
    }

    func linkReference(artifactId: String?, preferenceToken: String?, referenceId: String) async throws {
        var body: [String: Any] = ["referenceId": referenceId]
        if let artifactId { body["artifactId"] = artifactId }
        else if let preferenceToken { body["preferenceToken"] = preferenceToken }
        else { throw SammatiSDKError.invalidResponse }
        let data = try JSONSerialization.data(withJSONObject: body)
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
