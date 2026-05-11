// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "dm-annotate",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "dm-annotate", targets: ["DMAnnotate"]),
        .library(name: "DMAnnotateCore", targets: ["DMAnnotateCore"])
    ],
    targets: [
        .target(name: "DMAnnotateCore"),
        .executableTarget(
            name: "DMAnnotate",
            dependencies: ["DMAnnotateCore"]
        ),
        .testTarget(
            name: "DMAnnotateCoreTests",
            dependencies: ["DMAnnotateCore"]
        )
    ]
)
