// swift-tools-version: 5.9
import PackageDescription
import Foundation

// A source checkout builds without downloading weights or native artifacts.
// Running scripts/prepare-qwen-native.py installs the pinned optional framework.
let hasRuntime = FileManager.default.fileExists(atPath: URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().appendingPathComponent("Artifacts/LeuQwenNative.xcframework").path)
var targets: [Target] = []
if hasRuntime {
    targets.append(.binaryTarget(name: "LeuQwenNative", path: "Artifacts/LeuQwenNative.xcframework"))
}
var dependencies: [Target.Dependency] = [.product(name: "LeuReasoningCore", package: "LeuReasoningCore")]
if hasRuntime { dependencies.append("LeuQwenNative") }
targets.append(.target(name: "LeuQwenRuntime", dependencies: dependencies))
let package = Package(name: "LeuQwenRuntime", platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "LeuQwenRuntime", targets: ["LeuQwenRuntime"])],
    dependencies: [.package(path: "../LeuReasoningCore")], targets: targets)
