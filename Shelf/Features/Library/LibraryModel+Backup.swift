import Foundation

extension LibraryModel {
    func exportBackup() async {
        guard !busy else { return }
        operationLabel = "Creating a verified backup…"
        defer { operationLabel = nil; Task { await drainImports() } }
        do { shareFile = ShareFile(url: try await backup.export()) }
        catch { errorMessage = error.localizedDescription }
    }
    func restoreBackup(_ url: URL) async {
        guard !busy else { errorMessage = "Finish the current import before restoring a backup."; return }
        operationLabel = "Checking every PDF before restoring…"
        defer { operationLabel = nil; Task { await drainImports() } }
        do {
            let staged = try await incoming.stage(url)
            defer { staged.discard() }
            let result = try await backup.restore(from: staged.url)
            try await reload()
            announce("\(result.addedBooks) PDFs restored · \(result.matchedBooks) matched · \(result.addedAnnotations) notes added")
            isIndexing = true
            _ = await rebuilder.rebuildMissing()
            isIndexing = false
            try await reload()
        } catch { errorMessage = error.localizedDescription; isIndexing = false }
    }
}
