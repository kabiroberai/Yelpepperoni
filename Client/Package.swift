// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Client",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "Client",
            targets: ["Client"]
        ),
    ],
    dependencies: [
        .package(path: "../Common"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.0"),
    ],
    targets: [
        .target(
            name: "Client",
            dependencies: [
                "Common",
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ]
        ),
        .testTarget(
            name: "ClientTests",
            dependencies: ["Client"]
        ),
    ]
)
