import Foundation

public extension LibraryRepository {
    /// All original files are staged before a single atomic metadata commit.
    func mergeBackup(_ backup: StagedBackup, into vault: any DocumentVault) throws -> RestoreResult {
        let current = try open()
        let plan = try BackupMerger.plan(current: current, incoming: backup.snapshot)
        var copied: [UUID] = []
        var committed = false
        defer { if !committed { for id in copied { try? vault.removeOriginal(id: id) } } }
        for copy in plan.copies {
            try Task.checkCancellation()
            _ = try vault.stageCopy(from: backup.vault.originalURL(for: copy.source), id: copy.destination)
            copied.append(copy.destination)
        }
        try persistence.save(plan.snapshot)
        state = plan.snapshot
        committed = true
        return plan.result
    }
}
