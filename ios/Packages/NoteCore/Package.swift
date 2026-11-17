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
    name: "NoteCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "NoteCore", targets: ["NoteCore"]),
        .library(name: "NoteCoreTesting", targets: ["NoteCoreTesting"]),
    ],
    targets: [
        .target(name: "NoteCore", swiftSettings: strictSettings),
        .target(name: "NoteCoreTesting", dependencies: ["NoteCore"], swiftSettings: strictSettings),
        .testTarget(
            name: "NoteCoreTests", dependencies: ["NoteCore", "NoteCoreTesting"], swiftSettings: strictSettings),
    ]
)
