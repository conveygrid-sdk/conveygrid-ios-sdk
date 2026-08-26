import Foundation
import UIKit

final class MinorConsentFlow {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    @MainActor
    func run(noticeCode: String, identity: ConsentIdentity, presenter: UIViewController?) async throws -> ConsentResult {
        let notice = try await api.fetchPublishedNotice(noticeCode: noticeCode, mobile: identity.mobile)
        guard notice.supportsMinors == true else {
            throw SammatiSDKError.adultOnlyNotice
        }

        let response = try await api.submit(notice: notice, choices: [], identity: identity, language: identity.language)
        var mapped = api.mapResult(response)

        let mode = mapped.guardianVerificationMode.isEmpty
            ? (notice.guardianVerificationMode ?? "INVITATION_LINK")
            : mapped.guardianVerificationMode

        if mode == "REAL_TIME_VERIFICATION",
           let frame = mapped.guardianFrameUrl,
           let token = mapped.guardianSessionToken,
           let presenter {
            let verification = try await GuardianVerificationViewController.present(
                frameURL: frame,
                sessionToken: token,
                presenter: presenter
            )

            mapped = ConsentResult(
                artifactId: mapped.artifactId,
                subjectId: mapped.subjectId,
                allMandatoryGranted: verification.status == "granted" ? true : verification.allMandatoryGranted,
                preferenceToken: mapped.preferenceToken,
                status: verification.status == "granted" ? "granted" :
                    verification.status == "denied" ? "denied" : "guardian_verification_failed",
                linkRequired: mapped.linkRequired,
                linkExpiresAt: mapped.linkExpiresAt,
                dpType: mapped.dpType,
                minorConsentProfileId: verification.minorConsentProfileId ?? mapped.minorConsentProfileId,
                minorDpId: mapped.minorDpId,
                invitationStatus: mapped.invitationStatus,
                invitationLink: mapped.invitationLink,
                guardianVerificationMode: mode,
                guardianSessionToken: nil,
                guardianFrameUrl: nil,
                guardianVerificationPending: verification.status != "granted",
                realtimeStatus: verification.status,
                message: verification.message
            )
        }

        if mapped.linkRequired {
            PendingLinkStore.save(result: mapped)
        }

        return mapped
    }
}
