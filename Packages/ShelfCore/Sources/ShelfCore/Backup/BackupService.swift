import Foundation

public actor BackupService {
    private let repository: LibraryRepository
    private let vault: any DocumentVault
    private let temporaryDirectory: URL
    public init(repository: LibraryRepository, vault: any DocumentVault, temporaryDirectory: URL) {
        self.repository = repository; self.vault = vault; self.temporaryDirectory = temporaryDirectory
    }
    public func export() async throws -> URL {
        let snapshot = try await repository.snapshot()
        let folder = temporaryDirectory.appendingPathComponent("Shelf-Export-" + UUID().uuidString)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = folder.appendingPathComponent("Shelf-" + stamp).appendingPathExtension("shelfbackup")
        try BackupWriter().write(snapshot: snapshot, vault: vault, to: url)
        return url
    }
    public func restore(from source: URL) async throws -> RestoreResult {
        let staged = try BackupReader().stage(source, in: temporaryDirectory)
        defer { staged.discard() }
        return try await repository.mergeBackup(staged, into: vault)
    }
}
