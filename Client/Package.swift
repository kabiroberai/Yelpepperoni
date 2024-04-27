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
    targets: [
        .target(
            name: "Client"
        ),
        .testTarget(
            name: "ClientTests",
            dependencies: ["Client"]
        ),
    ]
)
