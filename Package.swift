// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SammatiNoticeSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SammatiNoticeSDK",
            targets: ["SammatiNoticeSDK"]
        )
    ],
    targets: [
        .target(
            name: "SammatiNoticeSDK",
            path: "Sources/SammatiNoticeSDK",
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .testTarget(
            name: "SammatiNoticeSDKTests",
            dependencies: ["SammatiNoticeSDK"],
            path: "Tests/SammatiNoticeSDKTests"
        )
    ]
)
