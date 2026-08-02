// swift-tools-version: 5.9

import Foundation
import PackageDescription

let includeLiveCoreTests =
    ProcessInfo.processInfo.environment["LEATHER_ENABLE_LIVE_CORE_TESTS"] == "1"

let package = Package(
    name: "KawaCAD",
    defaultLocalization: "ja",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "KawaCAD", targets: ["KawaCADApp"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-testing.git",
            revision: "5ee435b15ad40ec1f644b5eb9d247f263ccd2170"
        )
    ],
    targets: [
        .target(
            name: "KawaCADOutput",
            path: "Sources/KawaCADOutput",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "KawaCADApp",
            dependencies: [
                "KawaCADOutput"
            ],
            path: "Sources/KawaCADApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "KawaCADAppTests",
            dependencies: [
                "KawaCADApp",
                "KawaCADOutput",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/KawaCADAppTests",
            exclude: includeLiveCoreTests ? [] : [
                "LiveCoreConstraintIntegrationTests.swift"
            ]
        )
    ]
)
