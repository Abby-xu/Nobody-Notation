// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ScoreIMEKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ScoreIMEKit", targets: ["ScoreIMEKit"]),
    ],
    targets: [
        .target(
            name: "ScoreIMEKit",
            resources: [.process("Resources")]
        ),
    ]
)
