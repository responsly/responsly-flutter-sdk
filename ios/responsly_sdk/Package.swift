// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// One target: the plugin class plus the Responsly iOS SDK sources in
// Sources/responsly_sdk/ResponslySDK, which tool/sync_native.sh copies from the native
// repository. ios/responsly_sdk.podspec builds the same files for CocoaPods.
let package = Package(
    name: "responsly_sdk",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "responsly-sdk", targets: ["responsly_sdk"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "responsly_sdk",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // The privacy manifest of the native SDK (UserDefaults access, no tracking).
                .process("ResponslySDK/Resources/PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
