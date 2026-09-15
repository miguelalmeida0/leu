import Foundation
#if canImport(LeuQwenNative)
import LeuQwenNative
#endif

public enum QwenRuntimeError: Error, Sendable {
    case unavailable, cancelled, busy, inputTooLong, generationFailed, outputLimit, memoryBudget
}
public struct QwenRun: Sendable {
    public let json: Data
    public let promptTokens: Int
    public let outputTokens: Int
    public let loadMilliseconds: Double
    public let promptMilliseconds: Double
    public let firstTokenMilliseconds: Double
    public let totalMilliseconds: Double
    public let peakObservedFootprint: UInt64
}

/// Only immutable request inputs cross the worker queue. Cancellation has its
/// own lock and never waits for the synchronous C generation call to finish.
public final class EmbeddedQwen: @unchecked Sendable {
    public static let shared = EmbeddedQwen()
    public static var available: Bool {
        #if canImport(LeuQwenNative)
        return String(cString: leu_qwen_runtime_commit()) == "4c9233c034fc450dcf34c7c0988aebe6da5cdf1a"
        #else
        return false
        #endif
    }
    private let gate = NSLock()
    private var busy = false
    private let worker = DispatchQueue(label: "dev.leu.qwen.inference", qos: .userInitiated)
    private func acquire() -> Bool {
        gate.lock(); defer { gate.unlock() }
        guard !busy else { return false }; busy = true; return true
    }
    private func release() { gate.lock(); busy = false; gate.unlock() }
    public func run(model: URL, system: String, input: String, schema: String,
                    context: Int = 2048, outputLimit: Int = 512,
                    maximumFootprint: UInt64, developmentCPUOnly: Bool = false) async throws -> QwenRun {
        #if canImport(LeuQwenNative)
        guard Self.available else { throw QwenRuntimeError.unavailable }
        guard acquire() else { throw QwenRuntimeError.busy }
        let cancellation = Cancellation()
        defer { release() }
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                worker.async {
                    defer { cancellation.finish() }
                    var output = [CChar](repeating: 0, count: 32768)
                    var metrics = leu_qwen_metrics()
                    let result = leu_qwen_run(cancellation.handle, model.path, system, input, schema,
                        Int32(context), Int32(outputLimit), developmentCPUOnly ? 0 : 1,
                        maximumFootprint, &output, Int32(output.count), &metrics)
                    guard result == 0 else {
                        let error: QwenRuntimeError
                        switch result {
                        case 1: error = .cancelled
                        case 2: error = .busy
                        case 3: error = .inputTooLong
                        case 5: error = .outputLimit
                        case 6: error = .memoryBudget
                        default: error = .generationFailed
                        }
                        continuation.resume(throwing: error); return
                    }
                    let bytes = output.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
                    continuation.resume(returning: QwenRun(json: Data(bytes), promptTokens: Int(metrics.prompt_tokens),
                        outputTokens: Int(metrics.output_tokens), loadMilliseconds: metrics.load_ms,
                        promptMilliseconds: metrics.prompt_ms, firstTokenMilliseconds: metrics.first_token_ms,
                        totalMilliseconds: metrics.total_ms, peakObservedFootprint: metrics.peak_observed_footprint))
                }
            }
        }, onCancel: { cancellation.cancel() })
        #else
        throw QwenRuntimeError.unavailable
        #endif
    }
}

#if canImport(LeuQwenNative)
private final class Cancellation: @unchecked Sendable {
    let handle = leu_qwen_create()!
    private let lock = NSLock()
    private var finished = false
    func cancel() {
        lock.lock(); defer { lock.unlock() }
        if !finished { leu_qwen_cancel(handle) }
    }
    func finish() {
        lock.lock(); defer { lock.unlock() }
        if !finished { finished = true; leu_qwen_destroy(handle) }
    }
    deinit { finish() }
}
#endif
