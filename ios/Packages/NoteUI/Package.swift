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
    name: "NoteUI",
    platforms: [.iOS(.v26)],
    products: [.library(name: "NoteUI", targets: ["NoteUI"])],
    dependencies: [.package(path: "../NoteCore")],
    targets: [
        .target(
            name: "NoteUI",
            dependencies: ["NoteCore"],
            resources: [.copy("Fonts")],
            swiftSettings: strictSettings + [.defaultIsolation(MainActor.self)]
        )
    ]
)
