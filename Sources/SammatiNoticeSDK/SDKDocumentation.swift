/*
SammatiNoticeSDK — iOS Documentation
=====================================

SPM:
    .package(url: "https://github.com/conveygrid-sdk/conveygrid-ios-sdk.git", from: "1.0.0")

Usage:

    import SammatiNoticeSDK

    SammatiNotice.configure(
        SammatiConfiguration(
            clientId: "YOUR_CLIENT_ID",
            apiBaseURL: URL(string: "https://samatigridapidev.rysun.in")!,
            environment: .sandbox,
            theme: NoticeTheme(
                primaryColor: "#005BED",
                secondaryColor: "#F2621B",
                fontFamily: "HelveticaNeue"
            )
        )
    )

    let result = try await SammatiNotice.captureConsent(
        options: ConsentOptions(
            noticeCode: "LUXE",
            email: "user@example.com",
            mobile: "9999999999",
            fullName: "User"
        ),
        presenter: self
    )

Minor + Guardian Flow:

    let result = try await SammatiNotice.captureConsent(
        options: ConsentOptions(
            noticeCode: "LUXE",
            fullName: "Minor Name",
            email: "minor@example.com",
            mobile: "9999999999",
            dateOfBirth: "2015-05-10",
            guardian: Guardian(
                guardianName: "Guardian Name",
                guardianEmail: "guardian@example.com",
                guardianMobile: "8888888888",
                relationshipCode: "FATHER"
            )
        ),
        presenter: self
    )

Features & Compliance:
- Server-driven Notice Themes (`primary_color`, `secondary_color`, `font_family`, `logo_url` base64/http)
- Dynamic UI styling in ConsentViewController
- Minor/Guardian consent flow & realtime web verification frame
- Official PrivacyInfo.xcprivacy manifest for Apple App Store compliance
*/
