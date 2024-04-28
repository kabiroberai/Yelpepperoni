// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Server",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.4"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "4.0.0"),
        .package(url: "https://github.com/iansampson/AppAttest.git", revision: "f4fc1ea12c712d6833905d9c11c73c1601ae4001"),
        .package(path: "../Common"),
    ],
    targets: [
        .executableTarget(
            name: "Server",
            dependencies: [
                "Common",
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "AppAttest", package: "AppAttest"),
                .product(name: "PizzaDetection", package: "Common"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ServerTests",
            dependencies: [
                .target(name: "Server"),
                .product(name: "XCTVapor", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableExperimentalFeature("StrictConcurrency"),
] }
