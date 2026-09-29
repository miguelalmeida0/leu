// swift-tools-version: 5.9
// THROWAWAY — V37 capability spike only (branch `claude/v37-capability-spike`, never merged).
// The runner that calls Apple's on-device model on the Mac (and later from the iPhone host app).
// It depends on nothing outside this directory; Foundation Models code compiles only where the
// framework exists, so the package also builds and tests on Linux with the model compiled out.
import PackageDescription

let package = Package(
    name: "SpikeRunner",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "SpikeKit", targets: ["SpikeKit"]),
        .library(name: "SpikeFoundation", targets: ["SpikeFoundation"]),
        .executable(name: "spike-runner", targets: ["spike-runner"])
    ],
    targets: [
        .target(name: "SpikeKit"),
        .target(name: "SpikeFoundation", dependencies: ["SpikeKit"]),
        .executableTarget(name: "spike-runner", dependencies: ["SpikeKit", "SpikeFoundation"]),
        .testTarget(name: "SpikeKitTests", dependencies: ["SpikeKit"])
    ]
)
