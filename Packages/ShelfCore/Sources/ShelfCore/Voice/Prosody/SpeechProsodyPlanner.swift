import Foundation

public struct SpeechRateProfile: Codable, Equatable, Sendable {
    public var userMultiplier: Double
    public init(userMultiplier: Double = 1) { self.userMultiplier = min(max(userMultiplier, 0.8), 2) }
}

public struct SpeechProsodyPlanner: Sendable {
    public init() {}

    public func prosody(for kind: SpeechBlockKind, profile: SpeechRateProfile = SpeechRateProfile()) -> SpeechProsody {
        let base: SpeechProsody
        switch kind {
        case .heading: base = SpeechProsody(rateMultiplier: 0.90, pitchMultiplier: 0.99, prePause: 0.06, postPause: 0.16)
        case .code: base = SpeechProsody(rateMultiplier: 0.84, pitchMultiplier: 0.98, prePause: 0.04, postPause: 0.10)
        case .formula: base = SpeechProsody(rateMultiplier: 0.82, pitchMultiplier: 0.99, prePause: 0.04, postPause: 0.10)
        case .list: base = SpeechProsody(rateMultiplier: 0.95, pitchMultiplier: 1, prePause: 0.02, postPause: 0.08)
        case .quote: base = SpeechProsody(rateMultiplier: 0.94, pitchMultiplier: 0.99, prePause: 0.04, postPause: 0.10)
        case .caption, .metadata: base = SpeechProsody(rateMultiplier: 0.90, pitchMultiplier: 0.98, prePause: 0.03, postPause: 0.08)
        case .table: base = SpeechProsody(rateMultiplier: 0.82, pitchMultiplier: 0.98, prePause: 0.05, postPause: 0.12)
        case .prose: base = SpeechProsody(rateMultiplier: 1, pitchMultiplier: 1, prePause: 0, postPause: 0.055)
        }
        // Fast user speeds compress gaps while preserving structural differentiation.
        let compressedPause = max(0.012, base.postPause / max(1, profile.userMultiplier * 0.82))
        return SpeechProsody(rateMultiplier: base.rateMultiplier * profile.userMultiplier,
                             pitchMultiplier: base.pitchMultiplier,
                             prePause: base.prePause / max(1, profile.userMultiplier * 0.7),
                             postPause: compressedPause)
    }
}
