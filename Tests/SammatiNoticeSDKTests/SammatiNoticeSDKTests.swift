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
            apiBaseURL: URL(string: "https://example.com")!,
            environment: .sandbox
        )
        XCTAssertEqual(configuration.clientId, "test")
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
}

