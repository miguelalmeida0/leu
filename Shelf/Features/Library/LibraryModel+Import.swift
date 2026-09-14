import Foundation
import ShelfCore

extension LibraryModel {
    func receive(_ url: URL) {
        if url.pathExtension.lowercased() == "shelfbackup" {
            pendingBackupURL = url
        } else { enqueue([url]) }
    }

    func enqueue(_ urls: [URL]) {
        queuedURLs.append(contentsOf: urls)
        Task { await drainImports() }
    }

    func drainImports() async {
        guard phase == .ready, importLabel == nil, operationLabel == nil else { return }
        var added = 0, matched = 0
        var failures: [String] = []
        while !queuedURLs.isEmpty {
            let source = queuedURLs.removeFirst()
            importLabel = source.lastPathComponent
            do {
                let staged = try await incoming.stage(source)
                defer { staged.discard() }
                let result = try await importer.importDocument(at: staged.url, originalFilename: staged.originalFilename)
                if result.wasDuplicate { matched += 1 } else { added += 1 }
                try await reload()
            } catch { failures.append("\(source.lastPathComponent): \(error.localizedDescription)") }
        }
        importLabel = nil
        if added + matched > 0 {
            announce("\(added) saved on this iPhone" + (matched > 0 ? " · \(matched) already in your library" : ""))
        }
        if !failures.isEmpty { errorMessage = failures.joined(separator: "\n\n") }
        updateSearch()
    }

    func importPickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            errorMessage = nil
            // A successful picker action should always reveal the resulting book.
            // Do not leave the user filtered into an empty collection after import.
            selectedTab = .library
            selectedCollectionID = nil
            selectedTag = nil
            query = ""
            announce(urls.count == 1 ? "Importing PDF…" : "Importing \(urls.count) PDFs…")
            enqueue(urls)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
