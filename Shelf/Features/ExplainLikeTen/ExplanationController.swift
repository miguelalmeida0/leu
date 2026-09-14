import Foundation
import Combine
import ShelfCore

/// Feature state machine. Explicit states, one in-flight request, cancellation that
/// invalidates late results, coalesced taps, and at most one bounded retry.
@MainActor
final class ExplanationController: ObservableObject {
    enum State: Equatable {
        case idle
        case preparing
        case generating
        case validating
        case ready(ExplanationRecord)
        case needsContext(String)
        case unavailable(LearningModelState)
        case failed(String)
        case cancelled
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var mode: ExplanationMode = .standard
    /// The original selection. Refinements stay bound to this, never to the last answer.
    @Published private(set) var packet: ExplanationSourcePacket?
    @Published private(set) var diagnostics = ExplanationDiagnostics()

    private let provider: ExplanationIntelligenceProvider
    private let validator = ExplanationValidator()
    private let cache: ExplanationCache
    private var task: Task<Void, Never>?
    private var requestToken = UUID()
    var backend: String { provider.backend }

    init(provider: ExplanationIntelligenceProvider, cache: ExplanationCache? = nil) {
        self.provider = provider
        self.cache = cache ?? ExplanationCache()
    }

    var isBusy: Bool {
        switch state {
        case .preparing, .generating, .validating: return true
        default: return false
        }
    }

    func start(packet: ExplanationSourcePacket) {
        if self.packet != packet { reset() }
        self.packet = packet
        request(mode: .standard)
    }

    /// Primary refinement. Re-runs against the ORIGINAL packet with a simpler intent.
    func evenSimpler() { request(mode: .evenSimpler) }

    /// Secondary refinement.
    func showExample() { request(mode: .withExample) }

    func cancel() {
        finishActiveTrace()
        task?.cancel()
        task = nil
        requestToken = UUID()
        state = .cancelled
    }

    /// Closing or changing selection must invalidate in-flight work so a late result
    /// from passage A cannot appear over passage B.
    func reset() {
        finishActiveTrace()
        task?.cancel()
        task = nil
        requestToken = UUID()
        packet = nil
        mode = .standard
        state = .idle
    }

    private func request(mode newMode: ExplanationMode) {
        guard let packet else { state = .failed("No source selection."); return }
        // Coalesce: an identical in-flight request is not restarted.
        if isBusy && newMode == mode { return }
        finishActiveTrace()
        task?.cancel()
        let token = UUID()
        requestToken = token
        mode = newMode
        ExplanationAttemptTrace.emit("REQUEST_BEGIN", context: .init(packet: packet, mode: newMode,
            backend: backend, availability: nil, requestID: token, attempt: 1))
        state = .preparing
        task = Task { [weak self] in
            await self?.run(packet: packet, mode: newMode, token: token, allowRetry: true)
        }
    }

    private func run(packet: ExplanationSourcePacket, mode: ExplanationMode,
                     token: UUID, allowRetry: Bool, repairReasons: [String] = []) async {
        let backend = provider.backend
        let revision = provider.providerRevision
        let key = packet.cacheKey(mode: mode, backend: backend, providerRevision: revision)
        let trace = ExplanationAttemptTrace.Context(packet: packet, mode: mode, backend: backend,
            availability: nil, requestID: token, attempt: allowRetry ? 1 : 2)

        let cached = await cache.value(for: key)
        let forced = ExplanationAttemptTrace.forceGeneration(for: packet)
        ExplanationAttemptTrace.emit("CACHE_LOOKUP", context: trace,
            fields: ["validatedHit": cached != nil, "forceGeneration": forced])
        if let cached, !forced {
            var record = cached
            record.servedFromCache = true
            guard isCurrent(token, trace: trace) else { return }
            ExplanationAttemptTrace.emit("FINAL_STATE", context: trace, fields: ["state": "accepted", "fromCache": true])
            state = .ready(record)
            ExplanationAttemptTrace.emit("RECORD_INSTALLED", context: trace)
            return
        }

        guard isCurrent(token, trace: trace) else { return }
        let availability = await provider.availability()
        let attemptTrace = ExplanationAttemptTrace.Context(packet: packet, mode: mode, backend: backend,
            availability: availability, requestID: token, attempt: allowRetry ? 1 : 2)
        guard isCurrent(token, trace: attemptTrace) else { return }
        diagnostics.availability = availability
        guard availability == .available else {
            ExplanationAttemptTrace.emit("FINAL_STATE", context: attemptTrace, fields: ["state": "unavailable"])
            state = .unavailable(availability); return
        }

        state = .generating
        do {
            diagnostics.attempts += 1
            ExplanationAttemptTrace.emit("EXPLANATION_ATTEMPT", context: attemptTrace, fields: [
                "repair": !allowRetry, "repairFailureCodes": repairReasons
            ])
            let start = ProcessInfo.processInfo.systemUptime
            let candidate = try await ExplanationAttemptTrace.current.withValue(attemptTrace) {
                try await provider.explain(packet, mode: mode, repairReasons: repairReasons)
            }
            let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1000
            ExplanationAttemptTrace.decodedResult(candidate, context: attemptTrace, milliseconds: elapsed)
            guard isCurrent(token, trace: attemptTrace) else { return }
            diagnostics.responses += 1
            diagnostics.lastResponseMilliseconds = elapsed
            state = .validating
            let failures = validator.validate(candidate, packet: packet, mode: mode)
            let displayable = validator.isDisplayable(failures)
            let report = ExplanationValidationReport(failures)
            diagnostics.lastValidationFailures = report.failures
            diagnostics.lastValidationWarnings = report.warnings
            ExplanationAttemptTrace.emit("VALIDATION_RESULT", context: attemptTrace, fields: [
                "accepted": displayable && !candidate.needsContext, "displayable": displayable,
                "failureCodes": report.failures, "warningCodes": report.warnings
            ])
            if !allowRetry {
                ExplanationAttemptTrace.emit("REPAIR", context: attemptTrace, fields: [
                    "attempted": true, "failureCodesSupplied": repairReasons, "responseReturned": true,
                    "accepted": displayable && !candidate.needsContext])
            }
            guard displayable else {
                diagnostics.rejections += 1
                if allowRetry {
                    ExplanationAttemptTrace.emit("REPAIR", context: attemptTrace, fields: [
                        "attempted": true, "failureCodesSupplied": failures.map(\.code), "responseReturned": false])
                    // One bounded repair attempt, never a retry storm.
                    await run(packet: packet, mode: mode, token: token, allowRetry: false,
                              repairReasons: ExplanationRepair.reasons(candidate: candidate, mode: mode, failures: failures))
                } else {
                    ExplanationAttemptTrace.emit("FINAL_STATE", context: attemptTrace, fields: ["state": "failed"])
                    state = .failed("The explanation did not pass source checks, so it was discarded.")
                }
                return
            }
            if candidate.needsContext {
                ExplanationAttemptTrace.emit("FINAL_STATE", context: attemptTrace, fields: ["state": "needsContext"])
                state = .needsContext(candidate.needsContextReason ?? "This passage needs more context than it contains.")
                return
            }
            var record = ExplanationRecord(candidate: candidate, packet: packet, mode: mode,
                                           backend: backend, availability: availability,
                                           generatedAt: Date(), providerRevision: revision)
            record.servedFromCache = false
            diagnostics.accepted += 1
            await cache.store(record, for: key)
            ExplanationAttemptTrace.emit("CACHE_STORE", context: attemptTrace,
                fields: ["acceptedCandidate": true, "persistenceError": cache.lastPersistenceError as Any? ?? NSNull()])
            guard isCurrent(token, trace: attemptTrace) else { return }
            ExplanationAttemptTrace.emit("FINAL_STATE", context: attemptTrace, fields: ["state": "accepted", "fromCache": false])
            state = .ready(record)
            ExplanationAttemptTrace.emit("RECORD_INSTALLED", context: attemptTrace)
        } catch is CancellationError {
            guard isCurrent(token, trace: attemptTrace) else { return }
            ExplanationAttemptTrace.emit("FINAL_STATE", context: attemptTrace, fields: ["state": "cancelled"])
            state = .cancelled
        } catch let error as LearningIntelligenceError {
            guard isCurrent(token, trace: attemptTrace) else { return }
            ExplanationAttemptTrace.emit("PROVIDER_ERROR", context: attemptTrace, fields: ["error": String(describing: error)])
            diagnostics.lastError = String(describing: error)
            switch error {
            case .unavailable(let reported):
                ExplanationAttemptTrace.emit("FINAL_STATE", context: attemptTrace, fields: ["state": "unavailable"])
                state = .unavailable(reported)
            case .sourceIntegrityFailed:
                ExplanationAttemptTrace.emit("FINAL_STATE", context: attemptTrace, fields: ["state": "needsContext"])
                state = .needsContext("This passage could not be read cleanly enough to explain.")
            case .invalidResponse, .timedOut:
                if allowRetry {
                    ExplanationAttemptTrace.emit("REPAIR", context: attemptTrace, fields: [
                        "attempted": true, "failureCodesSupplied": [], "responseReturned": false,
                        "providerError": String(describing: error)])
                    await run(packet: packet, mode: mode, token: token, allowRetry: false)
                } else {
                    ExplanationAttemptTrace.emit("REPAIR", context: attemptTrace, fields: [
                        "attempted": true, "failureCodesSupplied": repairReasons, "responseReturned": false, "accepted": false])
                    ExplanationAttemptTrace.emit("FINAL_STATE", context: attemptTrace, fields: ["state": "failed"])
                    state = .failed("The explanation could not be produced.")
                }
            }
        } catch {
            guard isCurrent(token, trace: attemptTrace) else { return }
            diagnostics.lastError = "\((error as NSError).domain) \((error as NSError).code)"
            ExplanationAttemptTrace.emit("FINAL_STATE", context: attemptTrace,
                fields: ["state": "failed", "error": diagnostics.lastError ?? "unknown"])
            state = .failed("The explanation could not be produced.")
        }
    }

    private func isCurrent(_ token: UUID, trace: ExplanationAttemptTrace.Context) -> Bool {
        guard token != requestToken else { return true }
        ExplanationAttemptTrace.emit("REQUEST_DROPPED", context: trace, fields: [
            "reason": "staleRequest", "activeRequestID": requestToken.uuidString,
            "activeDocumentID": packet?.documentID.uuidString as Any? ?? NSNull(),
            "activePage": packet.map { $0.pageIndex + 1 } as Any? ?? NSNull()
        ])
        return false
    }

    private func finishActiveTrace() {
        guard isBusy, let packet else { return }
        ExplanationAttemptTrace.emit("FINAL_STATE", context: .init(packet: packet, mode: mode,
            backend: backend, availability: diagnostics.availability, requestID: requestToken, attempt: 1),
            fields: ["state": "cancelled"])
    }

    /// DEBUG observer only: the accepted record actually reached the SwiftUI content.
    func recordVisible(_ record: ExplanationRecord) {
        #if DEBUG
        guard case .ready(let installed) = state, installed == record else { return }
        ExplanationAttemptTrace.emit("VISIBLE_UI", context: .init(packet: record.packet, mode: record.mode,
            backend: record.backend, availability: record.availability, requestID: requestToken, attempt: 1))
        #endif
    }
}
