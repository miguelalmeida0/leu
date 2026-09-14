import Foundation
import CryptoKit
import ShelfCore

/// Explicit development diagnostics for one authorized PDF fingerprint and page only.
/// No trace, generated text, or source metadata is emitted by release builds.
enum ExplanationAttemptTrace {
    struct Context: Sendable {
        let packet: ExplanationSourcePacket
        let mode: ExplanationMode
        let backend: String
        let availability: LearningModelState?
        let requestID: UUID
        let attempt: Int
    }

    static let current = TaskLocal<Context?>(wrappedValue: nil)

    static func enabled(for packet: ExplanationSourcePacket) -> Bool {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        return environment["LEU_EXPLANATION_TRACE"] == "1" &&
            environment["LEU_EXPLANATION_TRACE_FINGERPRINT"] == packet.fingerprint &&
            environment["LEU_EXPLANATION_TRACE_PAGE"] == String(packet.pageIndex + 1)
        #else
        return false
        #endif
    }

    static func forceGeneration(for packet: ExplanationSourcePacket) -> Bool {
        #if DEBUG
        return enabled(for: packet) && ProcessInfo.processInfo.environment["LEU_EXPLANATION_FORCE_GENERATION"] == "1"
        #else
        return false
        #endif
    }

    static func emit(_ event: String, context: Context?, fields: @autoclosure () -> [String: Any] = [:]) {
        #if DEBUG
        guard let context, enabled(for: context.packet) else { return }
        var row: [String: Any] = [
            "event": event, "mode": context.mode.rawValue, "backend": context.backend,
            "availability": context.availability?.rawValue ?? "notChecked", "documentID": context.packet.documentID.uuidString,
            "page": context.packet.pageIndex + 1, "fingerprint": context.packet.fingerprint,
            "spanIDs": context.packet.spans.map(\.id), "promptVersion": ExplanationPrompt.version,
            "extractionVersion": context.packet.extractionVersion, "language": context.packet.language,
            "validatorVersion": ExplanationSchema.validatorVersion, "requestID": context.requestID.uuidString,
            "attempt": context.attempt, "platform": platform, "uptimeSeconds": ProcessInfo.processInfo.systemUptime
        ]
        fields().forEach { row[$0.key] = $0.value }
        ExplanationRequestArtifact.shared.receive(row)
        guard JSONSerialization.isValidJSONObject(row),
              let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]),
              let line = String(data: data, encoding: .utf8) else { return }
        storage.append(line)
        print("[leu-explanation] " + line)
        #endif
    }

    static func modelRequest(_ request: LearningExplanationRequest) {
        #if DEBUG
        guard let context = current.get(), enabled(for: context.packet) else { return }
        let digest = SHA256.hash(data: Data(request.instructions.utf8)).map { String(format: "%02x", $0) }.joined()
        emit("MODEL_REQUEST", context: context, fields: ["instructionsSHA256": digest,
            "instructionsUTF16Count": request.instructions.utf16.count,
            "allowedSpanIDs": request.allowedSpanIDs, "maximumWords": request.maximumWords])
        #endif
    }

    static func rawResult(_ json: String) {
        #if DEBUG
        guard let context = current.get(), enabled(for: context.packet) else { return }
        let object = json.utf16.count <= 20_000 ? try? JSONSerialization.jsonObject(with: Data(json.utf8)) : nil
        emit("MODEL_RESULT", context: context, fields: [
            "structuredStatus": object == nil ? "invalidJSON" : "returned",
            // Explicitly authorized fixture only (enabled fingerprint + page gate).
            // Keep the actual candidate so a structural rejection can be inspected.
            "rawStructuredCandidate": object as Any? ?? NSNull(),
            "utf16Count": json.utf16.count
        ])
        #endif
    }

    static func modelStructuredResult(_ json: String) {
        #if DEBUG
        guard let context = current.get(), enabled(for: context.packet), json.utf16.count <= 20_000,
              let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) else { return }
        emit("MODEL_STRUCTURED_RESPONSE", context: context, fields: ["rawModelStructuredResponse": object])
        #endif
    }

    static func decodedResult(_ candidate: ExplanationCandidate, context: Context?, milliseconds: Double) {
        #if DEBUG
        emit("MODEL_RESULT_DECODED", context: context, fields: [
            "structuredStatus": candidate.needsContext ? "needsContext" : "decoded",
            "wordCount": candidate.wordCount, "blockCount": candidate.blocks.count,
            "blockKinds": candidate.blocks.prefix(8).map { $0.kind.rawValue },
            "blockTextLengths": candidate.blocks.prefix(8).map { $0.text.count },
            "emptyBlockIndices": candidate.blocks.prefix(8).enumerated().compactMap {
                $0.element.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? $0.offset : nil
            },
            "needsContext": candidate.needsContext, "hasNeedsContextReason": candidate.needsContextReason != nil,
            "preservedTerm": candidate.preservedTerm.map { String($0.prefix(120)) } as Any? ?? NSNull(),
            "citedSpanIDs": candidate.blocks.prefix(8).map { Array($0.sourceSpanIDs.prefix(12)).map { String($0.prefix(80)) } },
            "latencyMilliseconds": milliseconds
        ])
        #endif
    }

    static func text(for packet: ExplanationSourcePacket?) -> String {
        #if DEBUG
        guard let packet, enabled(for: packet) else { return "" }
        return storage.text()
        #else
        return ""
        #endif
    }

    static func summary(for packet: ExplanationSourcePacket?) -> String {
        #if DEBUG
        guard let packet, enabled(for: packet) else { return "Trace disabled: fixture fingerprint/page did not match configuration." }
        return ExplanationRequestArtifact.shared.summary()
        #else
        return ""
        #endif
    }

    #if DEBUG
    private static var platform: String {
        #if targetEnvironment(simulator)
        return "iOS-simulator"
        #elseif os(iOS)
        return "iOS-device"
        #else
        return "macOS"
        #endif
    }
    private static let storage = Storage()
    private final class Storage: @unchecked Sendable {
        private let lock = NSLock()
        private var lines: [String] = []
        func append(_ line: String) {
            lock.lock(); defer { lock.unlock() }
            lines.append(line)
            while lines.count > 100 { lines.removeFirst() }
        }
        func text() -> String {
            lock.lock(); defer { lock.unlock() }
            return lines.joined(separator: "\n")
        }
    }
    #endif
}
