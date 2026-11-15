// swift-tools-version: 6.2
import PackageDescription

let strictSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .strictMemorySafety(),
    .treatAllWarnings(as: .error),
]

let package = Package(
    name: "NoteTelemetry",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "NoteTelemetry", targets: ["NoteTelemetry"])],
    targets: [
        .target(name: "NoteTelemetry", swiftSettings: strictSettings),
        .testTarget(name: "NoteTelemetryTests", dependencies: ["NoteTelemetry"], swiftSettings: strictSettings),
    ]
)
