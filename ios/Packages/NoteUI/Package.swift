// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NoteUI",
    platforms: [.iOS(.v26)],
    products: [.library(name: "NoteUI", targets: ["NoteUI"])],
    dependencies: [.package(path: "../NoteCore")],
    targets: [.target(name: "NoteUI", dependencies: ["NoteCore"], swiftSettings: [.treatAllWarnings(as: .error)])]
)
