import Foundation

/// Local, opt-in DEBUG instrumentation. Records event names, never reading content.
/// The same real actions run whether diagnostics are enabled or disabled.
@MainActor
enum StudyInteractionTrace {
    private nonisolated static let writeLock = NSLock()
    nonisolated static func record(_ event: String) {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["LEU_UI_DIAGNOSTICS"] == "1" else { return }
        writeLock.lock()
        defer { writeLock.unlock() }
        print("[leu-integration] \(event)")
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LeuUIDiagnostics", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("study-\(ProcessInfo.processInfo.processIdentifier).jsonl")
            if let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber,
               size.intValue > 1_048_576 { return }
            let record: [String: Any] = ["event": event,
                "timestamp": Date().timeIntervalSince1970, "pid": ProcessInfo.processInfo.processIdentifier]
            var data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            data.append(0x0A)
            if !FileManager.default.fileExists(atPath: url.path) {
                try data.write(to: url, options: [.atomic])
            } else {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            }
        } catch {
            // Diagnostics must never change the outcome of a user action.
            print("LEU_TRACE_UNAVAILABLE: \(error.localizedDescription)")
        }
        #endif
    }
}
