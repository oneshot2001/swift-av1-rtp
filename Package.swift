// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "swift-av1-rtp",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16)
    ],
    products: [
        .library(name: "AV1RTP", targets: ["AV1RTP"]),
        .library(name: "AV1VideoToolbox", targets: ["AV1VideoToolbox"]),
        .executable(name: "av1dump", targets: ["AV1Dump"])
    ],
    targets: [
        // Core depacketizer — Foundation only, theoretically Linux-portable
        .target(
            name: "AV1RTP",
            dependencies: []
        ),
        // Optional VideoToolbox bridge — Apple platforms only
        .target(
            name: "AV1VideoToolbox",
            dependencies: ["AV1RTP"]
        ),
        // CLI dump tool
        .executableTarget(
            name: "AV1Dump",
            dependencies: ["AV1RTP"],
            path: "Examples/AV1Dump"
        ),
        // Tests
        .testTarget(
            name: "AV1RTPTests",
            dependencies: ["AV1RTP", "AV1VideoToolbox"],
            resources: [.copy("Fixtures")]
        )
    ]
)
