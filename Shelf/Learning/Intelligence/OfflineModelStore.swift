import Foundation
import Observation
import CryptoKit

@MainActor @Observable
final class OfflineModelStore {
    static let shared = OfflineModelStore()
    nonisolated static let bytes: Int64 = 1_280_835_840
    nonisolated static let checksum = "aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223"
    nonisolated static let remote = URL(string: "https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/f6d5376be1edb4d416d56da11e5397a961aca8ae/Qwen3.5-2B-Q4_K_M.gguf")!
    var installed = false
    var busy = false
    var progress: Double = 0
    var message: String?
    var wifiOnly = true
    // Never persisted as enabled: every new app session starts with the
    // established provider, including after termination on untested hardware.
    var enabled = false
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var transfer: ModelTransfer?
    nonisolated static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Leu/OfflineQwen", isDirectory: true)
    }
    nonisolated static var modelURL: URL { directory.appendingPathComponent("Qwen3.5-2B-Q4_K_M.gguf") }
    nonisolated static var resumeURL: URL { directory.appendingPathComponent("download.resume") }
    init() { installed = FileManager.default.fileExists(atPath: Self.modelURL.path) }
    func cancel() { operation?.cancel(); transfer?.cancel() }

    func download() {
        guard !busy else { return }
        busy = true; message = nil; progress = 0
        let wifi = wifiOnly
        operation = Task {
            defer { busy = false; operation = nil; transfer = nil }
            do {
                try prepareSpace()
                let downloader = ModelTransfer(wifiOnly: wifi) { value in
                    Task { @MainActor in self.progress = value }
                }
                transfer = downloader
                let resume = try? Data(contentsOf: Self.resumeURL)
                let temporary = try await withTaskCancellationHandler(operation: {
                    try Task.checkCancellation()
                    return try await downloader.download(resume: resume)
                }, onCancel: { downloader.cancel() })
                try Task.checkCancellation()
                try await verifyAndPromote(temporary)
                try? FileManager.default.removeItem(at: Self.resumeURL)
                installed = true; message = "Downloaded. Offline model is off until you choose it."
            } catch {
                if let data = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data,
                   data.count < 1_048_576 { try? data.write(to: Self.resumeURL, options: .atomic) }
                else if !Task.isCancelled { try? FileManager.default.removeItem(at: Self.resumeURL) }
                message = Task.isCancelled ? "Download cancelled. You can resume it with Download." :
                    "The model could not be installed. Retry Download or import the approved file. Existing Teach Leu is available."
            }
        }
    }

    func importFile(_ url: URL) {
        guard !busy else { return }
        busy = true; message = nil; progress = 0
        operation = Task {
            defer { busy = false; operation = nil }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                try prepareSpace()
                let staging = Self.directory.appendingPathComponent(UUID().uuidString + ".staging")
                defer { try? FileManager.default.removeItem(at: staging) }
                let copy = Task.detached(priority: .utility) {
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
                    guard size == Int(Self.bytes) else { throw CocoaError(.fileReadCorruptFile) }
                    try Data().write(to: staging)
                    let input = try FileHandle(forReadingFrom: url)
                    let output = try FileHandle(forWritingTo: staging)
                    defer { try? input.close(); try? output.close() }
                    while let chunk = try input.read(upToCount: 4 * 1024 * 1024), !chunk.isEmpty {
                        try Task.checkCancellation(); try output.write(contentsOf: chunk)
                    }
                }
                try await withTaskCancellationHandler(operation: { try await copy.value }, onCancel: { copy.cancel() })
                try Task.checkCancellation()
                try await verifyAndPromote(staging)
                installed = true; message = "Imported. Offline model is off until you choose it."
            } catch { message = "Import did not finish or the file did not match the approved model." }
        }
    }

    func remove() {
        guard !busy else { return }
        enabled = false
        do {
            let files = (try? FileManager.default.contentsOfDirectory(at: Self.directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            var size: Int64 = 0
            for file in files where file == Self.modelURL || file == Self.resumeURL || file.pathExtension == "staging" {
                let bytes = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                try FileManager.default.removeItem(at: file); size += Int64(bytes)
            }
            installed = false
            message = "Removed \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) of model files. Your reading and learner data are kept."
        } catch { message = "The model could not be removed." }
    }

    private func prepareSpace() throws {
        var root = Self.directory
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        // Staging plus final asset plus margin. Advisory filesystem capacity is
        // checked again by the actual write, which can still fail safely.
        let free = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage ?? 0
        guard free > Self.bytes * 2 + 134_217_728 else { throw CocoaError(.fileWriteOutOfSpace) }
        // Interrupted validation/import stages are replaceable, never learner data.
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            where url.pathExtension == "staging" { try? FileManager.default.removeItem(at: url) }
    }

    private func verifyAndPromote(_ staging: URL) async throws {
        try await Self.verify(staging)
        try Task.checkCancellation()
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        var candidate = staging; try candidate.setResourceValues(values)
        if FileManager.default.fileExists(atPath: Self.modelURL.path) {
            _ = try FileManager.default.replaceItemAt(Self.modelURL, withItemAt: staging)
        } else { try FileManager.default.moveItem(at: staging, to: Self.modelURL) }
        progress = 1
    }
    nonisolated static func verify(_ url: URL) async throws {
        // Hashing runs away from UI with cooperative cancellation between chunks.
        let hashing = Task.detached(priority: .utility) {
            guard try url.resourceValues(forKeys: [.fileSizeKey]).fileSize == Int(bytes) else { throw CocoaError(.fileReadCorruptFile) }
            let file = try FileHandle(forReadingFrom: url); defer { try? file.close() }
            var hash = SHA256()
            while let chunk = try file.read(upToCount: 4 * 1024 * 1024), !chunk.isEmpty {
                try Task.checkCancellation(); hash.update(data: chunk)
            }
            let actual = hash.finalize().map { String(format: "%02x", $0) }.joined()
            guard actual == checksum else { throw CocoaError(.fileReadCorruptFile) }
        }
        try await withTaskCancellationHandler(operation: { try await hashing.value }, onCancel: { hashing.cancel() })
        try Task.checkCancellation()
    }
}

/// Native URLSession writes response bytes to disk and supplies actual progress.
/// One attempt per user action; no hidden retry or alternate model download.
private final class ModelTransfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDownloadTask?
    private var session: URLSession?
    private var continuation: CheckedContinuation<URL, Error>?
    private var cancelled = false
    private var staged: URL?
    private let wifiOnly: Bool
    private let progress: @Sendable (Double) -> Void
    init(wifiOnly: Bool, progress: @escaping @Sendable (Double) -> Void) {
        self.wifiOnly = wifiOnly; self.progress = progress
    }
    func download(resume: Data?) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock(); defer { lock.unlock() }
            if cancelled { continuation.resume(throwing: CancellationError()); return }
            self.continuation = continuation
            let config = URLSessionConfiguration.ephemeral
            config.allowsCellularAccess = !wifiOnly; config.allowsExpensiveNetworkAccess = !wifiOnly
            config.allowsConstrainedNetworkAccess = false
            config.timeoutIntervalForRequest = 60; config.timeoutIntervalForResource = 3600
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            self.session = session
            let task = resume.map { session.downloadTask(withResumeData: $0) } ?? session.downloadTask(with: OfflineModelStore.remote)
            self.task = task; task.resume()
        }
    }
    func cancel() {
        lock.lock(); cancelled = true; let active = task; lock.unlock()
        active?.cancel(byProducingResumeData: { data in
            if let data, data.count < 1_048_576 { try? data.write(to: OfflineModelStore.resumeURL, options: .atomic) }
        })
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > OfflineModelStore.bytes { cancel(); return }
        progress(min(0.99, Double(totalBytesWritten) / Double(OfflineModelStore.bytes)))
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200 || response.statusCode == 206 else { return }
        let destination = OfflineModelStore.directory.appendingPathComponent(UUID().uuidString + ".staging")
        do { try FileManager.default.moveItem(at: location, to: destination); staged = destination } catch { }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock(); let completion = continuation; continuation = nil; lock.unlock()
        if let error { completion?.resume(throwing: error) }
        else if let staged { completion?.resume(returning: staged) }
        else { completion?.resume(throwing: URLError(.badServerResponse)) }
        session.finishTasksAndInvalidate()
    }
}
