// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "ShelfCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "ShelfCore", targets: ["ShelfCore"])],
    targets: [
        // The semantic space is data the reader looks words up in: see scripts/build-semantic-space.py.
        .target(name: "ShelfCore", resources: [.copy("Resources/SemanticSpace")]),
        .testTarget(name: "ShelfCoreTests", dependencies: ["ShelfCore"])
    ]
)
