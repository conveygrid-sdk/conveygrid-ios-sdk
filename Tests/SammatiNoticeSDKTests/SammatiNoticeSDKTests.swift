import XCTest
@testable import SammatiNoticeSDK

final class SammatiNoticeSDKTests: XCTestCase {
    func testMinorDateOfBirth() {
        XCTAssertTrue(SammatiNotice.isMinorDateOfBirth("2015-05-10"))
        XCTAssertFalse(SammatiNotice.isMinorDateOfBirth("1985-05-10"))
    }

    func testSessionIdIsStable() {
        let first = SammatiNotice.getSessionId()
        let second = SammatiNotice.getSessionId()
        XCTAssertEqual(first, second)
        XCTAssertFalse(first.isEmpty)
    }

    func testConfigurationCanBeCreated() {
        let configuration = SammatiConfiguration(
            clientId: "test",
            origin: "https://test.com",
            apiBaseURL: URL(string: "https://example.com")!,
            environment: .sandbox
        )
        XCTAssertEqual(configuration.clientId, "test")
        XCTAssertEqual(configuration.origin, "https://test.com")
    }

    func testConfigurationRequiresClientIdAndOriginWithDefaults() {
        let configuration = SammatiConfiguration(
            clientId: "my_app_client_id",
            origin: "https://my-app.com"
        )
        XCTAssertEqual(configuration.clientId, "my_app_client_id")
        XCTAssertEqual(configuration.origin, "https://my-app.com")
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "https://conveygridapidev.rysun.in")!)
        XCTAssertEqual(configuration.environment, .sandbox)
        XCTAssertNil(configuration.theme)
    }

    func testConfigurationWithOptionalTheme() {
        let theme = NoticeTheme(
            primaryColor: "#005BED",
            secondaryColor: "#F2621B",
            fontFamily: "HelveticaNeue"
        )
        let configuration = SammatiConfiguration(
            clientId: "my_app_client_id",
            origin: "https://my-app.com",
            theme: theme
        )
        XCTAssertEqual(configuration.clientId, "my_app_client_id")
        XCTAssertEqual(configuration.origin, "https://my-app.com")
        XCTAssertEqual(configuration.apiBaseURL, SammatiConfiguration.defaultEnvironment.defaultBaseURL)
        XCTAssertEqual(configuration.environment, SammatiConfiguration.defaultEnvironment)
        XCTAssertEqual(configuration.theme?.primaryColor, "#005BED")
        XCTAssertEqual(configuration.theme?.secondaryColor, "#F2621B")
        XCTAssertEqual(configuration.theme?.fontFamily, "HelveticaNeue")
    }

    func testConvenienceConfigure() {
        SammatiNotice.configure(clientId: "quick_client_id", origin: "https://quick.com")
        let theme = NoticeTheme(primaryColor: "#005BED")
        SammatiNotice.configure(clientId: "quick_client_id", origin: "https://quick.com", theme: theme)
    }

    func testEmptyClientIdThrowsInvalidConfiguration() async {
        SammatiNotice.configure(clientId: "   ", origin: "https://example.com")
        do {
            _ = try await SammatiNotice.validateConsent(
                identity: ConsentIdentity(sessionId: "s1"),
                purposeCode: "P1"
            )
            XCTFail("Expected invalidConfiguration error")
        } catch let SammatiSDKError.invalidConfiguration(msg) {
            XCTAssertTrue(msg.contains("clientId"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEmptyOriginThrowsInvalidConfiguration() async {
        SammatiNotice.configure(clientId: "client123", origin: "   ")
        do {
            _ = try await SammatiNotice.validateConsent(
                identity: ConsentIdentity(sessionId: "s1"),
                purposeCode: "P1"
            )
            XCTFail("Expected invalidConfiguration error")
        } catch let SammatiSDKError.invalidConfiguration(msg) {
            XCTAssertTrue(msg.contains("origin"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWhitespaceSanitizationOnConfiguration() {
        let config = SammatiConfiguration(clientId: "  my_client  \n", origin: "  https://my-app.com/  \r")
        XCTAssertEqual(config.clientId, "my_client")
        XCTAssertEqual(config.origin, "https://my-app.com/")
    }

    func testDateParserAndAgeCalculator() {
        XCTAssertTrue(SammatiNotice.isMinorDateOfBirth("2015-05-10"))
        XCTAssertFalse(SammatiNotice.isMinorDateOfBirth("1985-05-10"))
        XCTAssertEqual(try? DateParser.normalized("2000-12-25"), "2000-12-25")
        XCTAssertThrowsError(try DateParser.normalized("invalid-date"))
    }

    func testGuardianValidator() {
        let valid = Guardian(
            guardianName: "Jane Doe",
            guardianEmail: "jane@example.com",
            relationshipCode: "MOTHER"
        )
        XCTAssertNoThrow(try GuardianValidator.validate(valid))

        let missingName = Guardian(guardianName: "", guardianEmail: "jane@example.com", relationshipCode: "MOTHER")
        XCTAssertThrowsError(try GuardianValidator.validate(missingName))

        let missingRelationship = Guardian(guardianName: "Jane", guardianEmail: "jane@example.com")
        XCTAssertThrowsError(try GuardianValidator.validate(missingRelationship))

        let missingContact = Guardian(guardianName: "Jane", relationshipCode: "MOTHER")
        XCTAssertThrowsError(try GuardianValidator.validate(missingContact))
    }

    func testPendingLinkStore() {
        let result = ConsentResult(
            artifactId: "art_123",
            preferenceToken: "token_abc",
            linkExpiresAt: Date(timeIntervalSinceNow: 3600)
        )
        PendingLinkStore.save(result: result)
        let loaded = PendingLinkStore.load()
        XCTAssertEqual(loaded?.artifactId, "art_123")
        XCTAssertEqual(loaded?.preferenceToken, "token_abc")

        PendingLinkStore.clear()
        XCTAssertNil(PendingLinkStore.load())
    }

    func testLanguageStore() {
        XCTAssertEqual(LanguageStore.normalize("  HI-IN  "), "hi-in")
        XCTAssertEqual(LanguageStore.normalize(""), "en")
    }

    func testKeychainStore() {
        let testKey = "test_security_key"
        KeychainStore.delete(forKey: testKey)

        XCTAssertTrue(KeychainStore.save(string: "secure_value_123", forKey: testKey))
        XCTAssertEqual(KeychainStore.loadString(forKey: testKey), "secure_value_123")

        KeychainStore.delete(forKey: testKey)
        XCTAssertNil(KeychainStore.loadString(forKey: testKey))
    }

    func testPendingLinkMigrationFromUserDefaults() {
        let testKey = "sammati_notice_pending_link"
        KeychainStore.delete(forKey: testKey)

        // Simulate legacy UserDefaults entry
        let pending = PendingConsent(artifactId: "legacy_art", preferenceToken: "legacy_tok", linkExpiresAt: nil)
        let legacyData = try! JSONEncoder().encode(pending)
        UserDefaults.standard.set(legacyData, forKey: testKey)

        // Load via PendingLinkStore should migrate to Keychain and clean UserDefaults
        let loaded = PendingLinkStore.load()
        XCTAssertEqual(loaded?.artifactId, "legacy_art")
        XCTAssertEqual(loaded?.preferenceToken, "legacy_tok")
        XCTAssertNil(UserDefaults.standard.data(forKey: testKey))

        PendingLinkStore.clear()
        XCTAssertNil(PendingLinkStore.load())
    }

    func testProductionConfigurationMapsToProductionBaseURL() {
        let configuration = SammatiConfiguration(
            clientId: "my_app_client_id",
            origin: "https://my-app.com",
            environment: .production
        )
        XCTAssertEqual(configuration.environment, .production)
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "https://samatigridapi.rysun.in")!)
    }

    func testCodableRequestsEncodeWithoutCrashingOnNilOptionals() throws {
        let validateReq = ValidateRequest(
            purposeCode: "P1",
            noticeCode: nil,
            referenceId: nil,
            sessionId: "s1"
        )
        let validateData = try JSONEncoder().encode(validateReq)
        XCTAssertFalse(validateData.isEmpty)
        let jsonStr = String(data: validateData, encoding: .utf8)
        XCTAssertTrue(jsonStr!.contains("\"purpose_code\":\"P1\""))
        XCTAssertFalse(jsonStr!.contains("notice_code"))
        XCTAssertFalse(jsonStr!.contains("reference_id"))

        let submitReq = SubmitRequest(
            noticeId: "N1",
            version: "1.0",
            choices: [SubmitChoice(purposeId: "P1", granted: true)],
            language: "en",
            pageUrl: "https://example.com",
            subject: SubmitSubject(sessionId: "s1", referenceId: nil, email: nil, mobile: nil, fullName: nil),
            subjectRef: nil,
            dataPrincipal: nil,
            guardian: nil
        )
        let submitData = try JSONEncoder().encode(submitReq)
        XCTAssertFalse(submitData.isEmpty)
        let submitJson = String(data: submitData, encoding: .utf8)
        XCTAssertFalse(submitJson!.contains("subject_ref"))
        XCTAssertFalse(submitJson!.contains("guardian"))
        XCTAssertFalse(submitJson!.contains("1990-01-01"))
    }

    func testKeychainStoreThreadSafety() {
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            let key = "concurrent_key_\(i % 5)"
            _ = KeychainStore.save(string: "val_\(i)", forKey: key)
            _ = KeychainStore.loadString(forKey: key)
            if i % 2 == 0 {
                KeychainStore.delete(forKey: key)
            }
        }
    }

    func testHTTPSEnforcementOnInsecureURL() async {
        let insecureConfig = SammatiConfiguration(
            clientId: "test_client",
            origin: "https://example.com",
            apiBaseURL: URL(string: "http://insecure-api.example.com")!,
            environment: .production
        )
        SammatiNotice.configure(insecureConfig)
        do {
            _ = try await SammatiNotice.validateConsent(
                identity: ConsentIdentity(sessionId: "s1"),
                purposeCode: "P1"
            )
            XCTFail("Expected insecure HTTP connection error")
        } catch let SammatiSDKError.serverError(msg) {
            XCTAssertTrue(msg.contains("Insecure HTTP connections are not allowed"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFlexibleBoolDecodingForNoticeAndPurpose() throws {
        // Test 1: snake_case boolean values
        let json1 = """
        {
            "notice_id": "n1",
            "notice_code": "NOTICE_1",
            "show_notice": false,
            "purposes": [
                {
                    "purpose_id": "p1",
                    "purpose_code": "EMAIL_MARKETING",
                    "is_mandatory": true,
                    "already_granted": true
                }
            ]
        }
        """.data(using: .utf8)!

        let notice1 = try JSONDecoder().decode(Notice.self, from: json1)
        XCTAssertEqual(notice1.showNotice, false)
        XCTAssertEqual(notice1.purposes.count, 1)
        XCTAssertEqual(notice1.purposes[0].mandatory, true)
        XCTAssertEqual(notice1.purposes[0].granted, true)

        // Test 2: camelCase strings and integers ("false", "1", "true")
        let json2 = """
        {
            "noticeId": "n2",
            "noticeCode": "NOTICE_2",
            "showNotice": "false",
            "purposes": [
                {
                    "purposeId": "p2",
                    "purposeCode": "SMS_MARKETING",
                    "isMandatory": "1",
                    "is_granted": "true"
                },
                {
                    "purposeId": "p3",
                    "purposeCode": "ANALYTICS",
                    "is_mandatory": 0,
                    "granted": 1
                }
            ]
        }
        """.data(using: .utf8)!

        let notice2 = try JSONDecoder().decode(Notice.self, from: json2)
        XCTAssertEqual(notice2.showNotice, false)
        XCTAssertEqual(notice2.purposes.count, 2)
        XCTAssertEqual(notice2.purposes[0].mandatory, true)
        XCTAssertEqual(notice2.purposes[0].granted, true)
        XCTAssertEqual(notice2.purposes[1].mandatory, false)
        XCTAssertEqual(notice2.purposes[1].granted, true)
    }

    func testGrantedConsentStoreOperations() {
        GrantedConsentStore.clear()
        let identity = ConsentIdentity(
            sessionId: "session_123",
            referenceId: "user_ref_456",
            email: "alice@example.com",
            mobile: "+91 98765 43210"
        )

        XCTAssertFalse(GrantedConsentStore.isGranted(noticeCode: "TEST_NOTICE", identity: identity))

        GrantedConsentStore.record(noticeCode: "TEST_NOTICE", identity: identity)

        // Same notice + same email
        let queryByEmail = ConsentIdentity(sessionId: "new_session", email: "alice@example.com")
        XCTAssertTrue(GrantedConsentStore.isGranted(noticeCode: "TEST_NOTICE", identity: queryByEmail))

        // Same notice + same mobile (filtered numbers)
        let queryByMobile = ConsentIdentity(sessionId: "new_session_2", mobile: "9876543210")
        XCTAssertTrue(GrantedConsentStore.isGranted(noticeCode: "TEST_NOTICE", identity: queryByMobile))

        // Same notice + same referenceId
        let queryByRef = ConsentIdentity(sessionId: "new_session_3", referenceId: "user_ref_456")
        XCTAssertTrue(GrantedConsentStore.isGranted(noticeCode: "TEST_NOTICE", identity: queryByRef))

        // Different notice code
        XCTAssertFalse(GrantedConsentStore.isGranted(noticeCode: "OTHER_NOTICE", identity: identity))

        // Different user
        let otherUser = ConsentIdentity(sessionId: "other_session", email: "bob@example.com")
        XCTAssertFalse(GrantedConsentStore.isGranted(noticeCode: "TEST_NOTICE", identity: otherUser))

        // Clear works
        GrantedConsentStore.clear()
        XCTAssertFalse(GrantedConsentStore.isGranted(noticeCode: "TEST_NOTICE", identity: identity))
    }

    func testClearConsentCache() {
        let identity = ConsentIdentity(sessionId: "s_test", email: "consent_user@example.com")
        GrantedConsentStore.record(noticeCode: "ONBOARDING", identity: identity)
        XCTAssertTrue(GrantedConsentStore.isGranted(noticeCode: "ONBOARDING", identity: identity))

        SammatiNotice.clearConsentCache()
        XCTAssertFalse(GrantedConsentStore.isGranted(noticeCode: "ONBOARDING", identity: identity))
    }

    @MainActor
    func testConsentViewControllerPresentSkipsWhenNoticeShowNoticeIsFalse() async throws {
        let dummyVC = UIViewController()
        let notice = Notice(
            noticeId: "n_test",
            noticeCode: "TEST",
            showNotice: false,
            purposes: [
                Purpose(purposeId: "p1", purposeCode: "P1", isMandatory: true, alreadyGranted: false)
            ]
        )

        let selection = try await ConsentViewController.present(notice: notice, presenter: dummyVC)
        XCTAssertFalse(selection.cancelled)
        XCTAssertEqual(selection.choices.count, 1)
        XCTAssertEqual(selection.choices[0].purposeId, "p1")
        XCTAssertEqual(selection.choices[0].granted, false)
    }

    @MainActor
    func testConsentViewControllerPresentSkipsWhenAllPurposesAlreadyGranted() async throws {
        let dummyVC = UIViewController()
        let notice = Notice(
            noticeId: "n_test_2",
            noticeCode: "TEST_2",
            showNotice: true,
            purposes: [
                Purpose(purposeId: "p1", purposeCode: "P1", isMandatory: true, alreadyGranted: true),
                Purpose(purposeId: "p2", purposeCode: "P2", isMandatory: false, alreadyGranted: true)
            ]
        )

        let selection = try await ConsentViewController.present(notice: notice, presenter: dummyVC)
        XCTAssertFalse(selection.cancelled)
        XCTAssertEqual(selection.choices.count, 2)
        XCTAssertTrue(selection.choices[0].granted)
        XCTAssertTrue(selection.choices[1].granted)
    }

    func testParsePublishedNoticeWithEnvelopeLevelShowNoticeFalse() throws {
        let json = """
        {
            "success": true,
            "message": "Notice fetched successfully",
            "show_notice": false,
            "data": {
                "notice_id": "nid_1",
                "notice_code": "NOTICE_1",
                "version": "1.0",
                "notice_name": "Terms of Service",
                "purposes": [
                    {
                        "purpose_id": "p1",
                        "purpose_code": "MARKETING",
                        "is_mandatory": true,
                        "already_granted": false
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let client = APIClient(configuration: SammatiConfiguration(clientId: "client", origin: "https://example.com"))
        let notice = try client.parsePublishedNotice(from: json)

        XCTAssertEqual(notice.showNotice, false)
        XCTAssertEqual(notice.noticeId, "nid_1")
        XCTAssertEqual(notice.noticeCode, "NOTICE_1")
        XCTAssertEqual(notice.message, "Notice fetched successfully")
    }

    func testParsePublishedNoticeWithShownoticeLowercased() throws {
        let json = """
        {
            "success": true,
            "shownotice": false,
            "message": "Consent already provided",
            "data": {
                "notice_id": "nid_2",
                "notice_code": "NOTICE_2"
            }
        }
        """.data(using: .utf8)!

        let client = APIClient(configuration: SammatiConfiguration(clientId: "client", origin: "https://example.com"))
        let notice = try client.parsePublishedNotice(from: json)

        XCTAssertEqual(notice.showNotice, false)
        XCTAssertEqual(notice.noticeId, "nid_2")
    }

    func testParsePublishedNoticeWithShownoticeStringAndNumber() throws {
        let jsonString = """
        {
            "success": true,
            "show_notice": "false",
            "data": {
                "notice_code": "NOTICE_3"
            }
        }
        """.data(using: .utf8)!

        let jsonZero = """
        {
            "success": true,
            "shownotice": 0,
            "data": {
                "notice_code": "NOTICE_4"
            }
        }
        """.data(using: .utf8)!

        let client = APIClient(configuration: SammatiConfiguration(clientId: "client", origin: "https://example.com"))
        let notice1 = try client.parsePublishedNotice(from: jsonString)
        let notice2 = try client.parsePublishedNotice(from: jsonZero)

        XCTAssertEqual(notice1.showNotice, false)
        XCTAssertEqual(notice2.showNotice, false)
    }

    func testParsePublishedNoticeWithNoDataObject() throws {
        let json = """
        {
            "success": true,
            "show_notice": false,
            "message": "Consent has already been provided for all requested purposes."
        }
        """.data(using: .utf8)!

        let client = APIClient(configuration: SammatiConfiguration(clientId: "client", origin: "https://example.com"))
        let notice = try client.parsePublishedNotice(from: json)

        XCTAssertEqual(notice.showNotice, false)
        XCTAssertEqual(notice.message, "Consent has already been provided for all requested purposes.")
    }

    @MainActor
    func testConsentViewControllerDirectViewDidLoadSkipsWhenShowNoticeIsFalse() {
        var completedSelection: ConsentViewController.Selection?
        let notice = Notice(noticeId: "test_n", showNotice: false)
        let vc = ConsentViewController(notice: notice) { sel in
            completedSelection = sel
        }

        _ = vc.view // Triggers viewDidLoad()

        XCTAssertNotNil(completedSelection)
        XCTAssertFalse(completedSelection!.cancelled)
    }

    func testDebugLoggingToggle() {
        let initial = SammatiLogger.isDebugEnabled
        defer { SammatiLogger.isDebugEnabled = initial }

        SammatiNotice.enableDebugLogging(false)
        XCTAssertFalse(SammatiLogger.isDebugEnabled)

        SammatiNotice.enableDebugLogging(true)
        XCTAssertTrue(SammatiLogger.isDebugEnabled)
    }

    func testLoggerPrettyPrintAndFormattedLogging() {
        let jsonStr = "{\"show_notice\":false,\"notice_code\":\"TEST_01\",\"count\":42}"
        let data = jsonStr.data(using: .utf8)!
        let pretty = SammatiLogger.prettyJsonString(from: data)
        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertTrue(pretty.contains("\"show_notice\" : false") || pretty.contains("\"show_notice\": false"))

        // Ensure logRequest and logResponse execute without crash
        let url = URL(string: "https://conveygridapidev.rysun.in/api/v1/public/consent/notices/TEST_01/published?email=user%40example.com")!
        SammatiLogger.logRequest(
            url: url,
            method: "GET",
            headers: ["X-Application-Key": "my-secret-key-12345", "Origin": "https://example.com"],
            body: nil
        )

        SammatiLogger.logResponse(
            url: url,
            method: "GET",
            statusCode: 200,
            data: data,
            durationMs: 145.2
        )
    }
}

