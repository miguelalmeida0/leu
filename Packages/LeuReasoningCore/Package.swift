// swift-tools-version: 5.9
import PackageDescription

// LeuReasoningCore is intentionally isolated: no SwiftUI, no app target, no
// dependency on ShelfCore. It is a pure-Foundation reasoning engine that a
// later Leu version can adopt behind an adapter.
let package = Package(
    name: "LeuReasoningCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "LeuReasoningCore", targets: ["LeuReasoningCore"])],
    targets: [
        .target(name: "LeuReasoningCore"),
        .testTarget(
            name: "LeuReasoningCoreTests",
            dependencies: ["LeuReasoningCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
