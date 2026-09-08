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
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "https://samatigridapidev.rysun.in")!)
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
        XCTAssertEqual(configuration.apiBaseURL, SammatiConfiguration.defaultAPIBaseURL)
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
}

