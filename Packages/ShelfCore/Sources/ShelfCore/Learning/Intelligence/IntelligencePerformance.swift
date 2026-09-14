import Foundation

/// Bounded, content-free diagnostics. No source text or learner answers leave the
/// process. Callers can export samples when diagnosing a local performance run.
public enum IntelligencePerformance {
    public struct Sample: Codable, Sendable {
        public let stage: String
        public let milliseconds: Double
        public let workCount: Int
        public let bytes: Int
        public let cacheHit: Bool
    }
    private final class Buffer: @unchecked Sendable {
        let lock = NSLock()
        var samples: [Sample] = []
    }
    private static let buffer = Buffer()
    public static func record(_ stage: String, since start: UInt64, workCount: Int = 0, bytes: Int = 0, cacheHit: Bool = false) {
        let sample = Sample(stage: stage, milliseconds: Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000,
            workCount: workCount, bytes: bytes, cacheHit: cacheHit)
        buffer.lock.lock(); defer { buffer.lock.unlock() }
        if buffer.samples.count >= 256 { buffer.samples.removeFirst(64) }
        buffer.samples.append(sample)
    }
    public static func samples() -> [Sample] {
        buffer.lock.lock(); defer { buffer.lock.unlock() }; return buffer.samples
    }
}
