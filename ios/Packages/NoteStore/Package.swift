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
    name: "NoteStore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "NoteStore", targets: ["NoteStore"])],
    dependencies: [
        .package(path: "../NoteCore"),
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.12.0"),
    ],
    targets: [
        .target(
            name: "NoteStore",
            dependencies: ["NoteCore", .product(name: "GRDB", package: "GRDB.swift")],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "NoteStoreTests",
            dependencies: ["NoteStore", "NoteCore", .product(name: "GRDB", package: "GRDB.swift")],
            swiftSettings: strictSettings
        ),
    ]
)
