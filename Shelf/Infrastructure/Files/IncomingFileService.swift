import Foundation
import ShelfCore

struct IncomingFile: Sendable {
    let url: URL
    let originalFilename: String
    func discard() { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
}

/// Materializes file-provider URLs under coordinated, security-scoped access off the UI actor.
actor IncomingFileService {
    private let temporary: URL
    init(temporary: URL) { self.temporary = temporary }
    func stage(_ source: URL) throws -> IncomingFile {
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }
        let folder = temporary.appendingPathComponent("Incoming-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var retained = false
        defer { if !retained { try? FileManager.default.removeItem(at: folder) } }
        let name = source.lastPathComponent.isEmpty ? "Document.pdf" : source.lastPathComponent
        let target = folder.appendingPathComponent(name)
        var coordinationError: NSError?
        var result: Result<Void, Error> = .failure(ShelfError.invalidPDF("The provider did not supply a file."))
        NSFileCoordinator().coordinate(readingItemAt: source, options: .withoutChanges,
                                        error: &coordinationError) { readable in
            result = Result { try FileManager.default.copyItem(at: readable, to: target) }
        }
        if let coordinationError { throw coordinationError }
        try result.get()
        retained = true
        return IncomingFile(url: target, originalFilename: name)
    }
}
