import Foundation

public struct IntelligenceCapabilityReport: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable { case available, unavailable, restricted, failed }
    public let foundationModels: Status
    public let reason: String
    public let generationVerified: Bool
    public let errorChain: [String]
    public static let fallbackMessage = "On-device generative intelligence isn't available on this device."
    public init(availability: LearningModelState, generationVerified: Bool = false, error: Error? = nil) {
        self.generationVerified = generationVerified
        if let error {
            foundationModels = .failed; errorChain = Self.chain(error as NSError)
            reason = errorChain.contains("ModelManagerServices.ModelManagerError:1008")
                ? "Model service rejected generation (1008). Availability alone did not establish inference; underlying cause is not exposed by the public error."
                : "Generation failed after capability checking. Inspect the internal error chain."
        } else {
            errorChain = []
            switch availability {
            case .available:
                foundationModels = .available
                reason = generationVerified ? "An actual on-device response was received." : "Framework reports available; generation has not been verified."
            case .appleIntelligenceDisabled:
                foundationModels = .restricted; reason = "Apple Intelligence is not enabled."
            case .unsupportedDevice:
                foundationModels = .unavailable; reason = "Framework reports this device is not eligible."
            case .unsupportedOS:
                foundationModels = .unavailable; reason = "This OS does not support the required Foundation Models API."
            case .modelNotReady:
                foundationModels = .unavailable; reason = "Framework reports model assets are not ready."
            case .failed, .timedOut:
                foundationModels = .failed; reason = "The generation operation failed or timed out."
            case .loading, .cancelled, .unavailable:
                foundationModels = .unavailable; reason = "Generation capability has not been established for this operation."
            }
        }
    }
    private static func chain(_ error: NSError, depth: Int = 0) -> [String] {
        guard depth < 8 else { return [] }
        var values = ["\(error.domain):\(error.code)"]
        if let child = error.userInfo[NSUnderlyingErrorKey] as? NSError { values += chain(child, depth: depth + 1) }
        for child in error.userInfo["NSMultipleUnderlyingErrors"] as? [NSError] ?? [] { values += chain(child, depth: depth + 1) }
        for child in error.userInfo["NSMultipleUnderlyingErrorsKey"] as? [NSError] ?? [] { values += chain(child, depth: depth + 1) }
        return Array(Set(values)).sorted()
    }
}
