// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NoteCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "NoteCore", targets: ["NoteCore"])],
    targets: [.target(name: "NoteCore", swiftSettings: [.treatAllWarnings(as: .error)])]
)
