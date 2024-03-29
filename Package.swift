// swift-tools-version: 5.7.1

import PackageDescription

let package = Package(
    name: "DenBlocklists",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.4.0"),
        .package(url: "https://github.com/AdguardTeam/SafariConverterLib", from: "2.0.48"),
    ],
    targets: [
        .executableTarget(
            name: "DenBlocklists",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ContentBlockerConverter", package: "SafariConverterLib")
            ]
        )
    ]
)
