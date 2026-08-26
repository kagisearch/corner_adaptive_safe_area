// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "corner_adaptive_safe_area",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(
            name: "corner-adaptive-safe-area",
            targets: ["corner_adaptive_safe_area"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "corner_adaptive_safe_area",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
