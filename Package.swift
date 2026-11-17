// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Knurlink",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "KnurlinkCore"),
        .executableTarget(name: "Knurlink", dependencies: ["KnurlinkCore"]),
        .testTarget(name: "KnurlinkCoreTests", dependencies: ["KnurlinkCore"]),
    ]
)
