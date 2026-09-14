#if DEBUG
import Foundation

/// Receives only redacted production events. Each request has at most two attempts.
/// All writes and fsyncs finish before emit(FINAL_STATE) returns to the controller.
final class ExplanationRequestArtifact: @unchecked Sendable {
    static let shared = ExplanationRequestArtifact()
    private let lock = NSLock()
    private var requests: [String: [String: Any]] = [:]
    private var order: [String] = []
    private var activeID: String?
    private var writeStatus: [String: String] = [:]
    private let outputDirectories: [URL]?

    init(outputDirectories: [URL]? = nil) { self.outputDirectories = outputDirectories }

    func receive(_ event: [String: Any]) {
        lock.lock(); defer { lock.unlock() }
        guard let id = event["requestID"] as? String, let name = event["event"] as? String else { return }
        if requests[id] == nil {
            guard name == "REQUEST_BEGIN" else { return } // Never resurrect evicted, stale work.
            activeID = id
            order.append(id)
            while order.count > 12 {
                let old = order.removeFirst(); requests[old] = nil; writeStatus[old] = nil
            }
            var initial = event.filter { ["requestID", "mode", "backend", "availability", "documentID", "page",
                "fingerprint", "spanIDs", "extractionVersion", "promptVersion", "validatorVersion", "platform"].contains($0.key) }
            initial["traceFormatVersion"] = 3
            initial["startedAt"] = ISO8601DateFormatter().string(from: Date())
            initial["startedUptime"] = event["uptimeSeconds"]
            initial["bundleID"] = Bundle.main.bundleIdentifier ?? "unknown"
            initial["osVersion"] = ProcessInfo.processInfo.operatingSystemVersionString
            initial["simulatorID"] = ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? NSNull() as Any
            initial["attempts"] = [[String: Any]]()
            initial["repairAttempted"] = false
            initial["finalState"] = "preparing"
            initial["finalAccepted"] = false
            initial["visibleUIObserved"] = false
            initial["recordInstalled"] = false
            requests[id] = initial
        }
        guard var row = requests[id] else { return }
        if let availability = event["availability"] as? String, availability != "notChecked" {
            row["availability"] = availability
        }
        var attempts = row["attempts"] as? [[String: Any]] ?? []
        let number = event["attempt"] as? Int ?? 1
        if name == "EXPLANATION_ATTEMPT", (1...2).contains(number), attempts.count < number {
            attempts.append(["attempt": number, "responseReceived": false, "wordCount": NSNull(),
                "blockCount": NSNull(), "preservedTerm": NSNull(), "citedSpanIDs": [],
                "validationAccepted": NSNull(), "validationFailures": [], "validationWarnings": [],
                "startedUptime": event["uptimeSeconds"] ?? 0])
            if number == 2 { row["repairAttempted"] = true }
        }
        if let index = attempts.firstIndex(where: { ($0["attempt"] as? Int) == number }) {
            switch name {
            case "MODEL_REQUEST": attempts[index]["generateExplanationJSONCalled"] = true
            case "MODEL_STRUCTURED_RESPONSE":
                attempts[index]["responseReceived"] = true
                attempts[index]["rawModelStructuredResponse"] = event["rawModelStructuredResponse"]
            case "MODEL_RESULT":
                attempts[index]["responseReceived"] = true
                attempts[index]["structuredStatus"] = event["structuredStatus"]
                attempts[index]["rawStructuredCandidate"] = event["rawStructuredCandidate"]
            case "MODEL_RESULT_DECODED":
                for key in ["wordCount", "blockCount", "preservedTerm", "citedSpanIDs", "latencyMilliseconds",
                            "blockKinds", "blockTextLengths", "emptyBlockIndices", "needsContext", "hasNeedsContextReason"] {
                    attempts[index][key] = event[key]
                }
                attempts[index]["responseReceived"] = true
                attempts[index]["decoded"] = true
            case "VALIDATION_RESULT":
                attempts[index]["validationAccepted"] = event["accepted"]
                attempts[index]["validationFailures"] = event["failureCodes"]
                attempts[index]["validationWarnings"] = event["warningCodes"] ?? []
            case "PROVIDER_ERROR": attempts[index]["providerError"] = event["error"]
            default: break
            }
            if ["MODEL_STRUCTURED_RESPONSE", "MODEL_RESULT", "PROVIDER_ERROR"].contains(name),
               let start = attempts[index]["startedUptime"] as? Double,
               let now = event["uptimeSeconds"] as? Double {
                attempts[index]["latencyMilliseconds"] = (now - start) * 1000
            }
        }
        row["attempts"] = attempts
        if name == "REPAIR" { row["repairScheduled"] = true }
        if name == "CACHE_STORE" {
            row["cacheStoreCompleted"] = true
            row["persistenceError"] = event["persistenceError"]
        }
        if name == "REQUEST_DROPPED" {
            row["droppedReason"] = event["reason"]
            row["finalState"] = "dropped"
            row["finalAccepted"] = false
        }
        if name == "FINAL_STATE" {
            let state = event["state"] as? String ?? "unknown"
            row["finalState"] = state == "accepted" ? "ready" : state
            row["finalAccepted"] = state == "accepted"
            row["fromCache"] = event["fromCache"] ?? false
            row["error"] = event["error"] ?? NSNull()
            if let start = row["startedUptime"] as? Double, let now = event["uptimeSeconds"] as? Double {
                row["totalLatencyMilliseconds"] = (now - start) * 1000
            }
            row["finalStatePreparedAt"] = ISO8601DateFormatter().string(from: Date())
        }
        if name == "VISIBLE_UI" { row["visibleUIObserved"] = true }
        if name == "RECORD_INSTALLED" { row["recordInstalled"] = true }
        row["lastEvent"] = name
        requests[id] = row
        writeStatus[id] = persist(row, id: id)
    }

    func summary() -> String {
        lock.lock(); defer { lock.unlock() }
        guard let id = activeID, let row = requests[id] else { return "Trace: no request recorded" }
        let attempts = row["attempts"] as? [[String: Any]] ?? []
        var lines = ["Request: \(id)", "Mode: \(row["mode"] ?? "unknown")",
            "Attempts: \(attempts.count)",
            "Responses: \(attempts.filter { $0["responseReceived"] as? Bool == true }.count)",
            "Rejections: \(attempts.filter { $0["validationAccepted"] as? Bool == false }.count)"]
        for attempt in attempts {
            let accepted = attempt["validationAccepted"] as? Bool
            let status = accepted.map { $0 ? "accepted" : "rejected" } ?? "not validated"
            lines.append("Attempt \(attempt["attempt"] ?? "?"): \(status)")
            lines.append("Failure codes: \((attempt["validationFailures"] as? [String] ?? []).joined(separator: ", "))")
            lines.append("Warning codes: \((attempt["validationWarnings"] as? [String] ?? []).joined(separator: ", "))")
            if let kinds = attempt["blockKinds"] as? [String] { lines.append("Blocks: " + kinds.joined(separator: ", ")) }
            if let error = attempt["providerError"] as? String { lines.append("Provider: \(error)") }
            if let latency = attempt["latencyMilliseconds"] as? Double {
                lines.append(String(format: "Inference: %.0f ms", latency))
            }
        }
        lines.append("Repair: \(row["repairAttempted"] as? Bool == true ? "attempted" : "not attempted")")
        lines.append("Final state: \(row["finalState"] ?? "unknown")")
        lines.append(writeStatus[id] ?? "Artifact: not written")
        return lines.joined(separator: "\n")
    }

    private func persist(_ row: [String: Any], id: String) -> String {
        let manager = FileManager.default
        let platform = row["platform"] as? String ?? "unknown"
        let stem = platform.hasPrefix("iOS") ? "ios-generation" : "macos-generation"
        var roots = [manager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ExplanationDiagnostics", isDirectory: true)]
        #if targetEnvironment(simulator)
        // The production app authors the workspace mirror, including for bare xcodebuild.
        // The container copy remains usable if this development-only mirror is denied.
        let workspace = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        roots.append(workspace.appendingPathComponent("recovery-evidence/explanation-ios-p0", isDirectory: true))
        #endif
        if let outputDirectories { roots = outputDirectories }
        var status: [String] = []
        for root in roots {
            do {
                let directory = root.appendingPathComponent(stem, isDirectory: true)
                try manager.createDirectory(at: directory, withIntermediateDirectories: true)
                let file = directory.appendingPathComponent(id + ".json")
                var output = row
                output["artifactPath"] = file.path
                let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
                try flush(data, to: file)
                if activeID == id { try flush(data, to: root.appendingPathComponent("latest-" + stem + ".json")) }
                // Retain only this diagnostic's files. No library or study-cache access.
                let files = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
                    .filter { $0.pathExtension == "json" && UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil }
                    .sorted { modified($0) > modified($1) }
                for old in files.dropFirst(12) { try manager.removeItem(at: old) }
                status.append("Artifact flushed: " + file.path)
            } catch {
                let failure = error as NSError
                status.append("Artifact write failed: \(root.path) [\(failure.domain) \(failure.code)]")
            }
        }
        return status.joined(separator: "\n")
    }

    private func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func flush(_ data: Data, to url: URL) throws {
        // Explicit sibling path avoids Foundation choosing an unrelated temporary directory.
        let pending = url.appendingPathExtension("pending")
        try data.write(to: pending)
        let handle = try FileHandle(forWritingTo: pending)
        defer { try? handle.close() }
        try handle.synchronize()
        // POSIX rename replaces only our diagnostic file and is atomic on this volume.
        guard rename(pending.path, url.path) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }
}
#endif
