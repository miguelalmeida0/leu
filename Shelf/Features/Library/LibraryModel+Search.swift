import Foundation
import ShelfCore

extension LibraryModel {
    func updateSearch() {
        searchTask?.cancel()
        passages = []
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2 else { isSearching = false; return }
        isSearching = true
        let books = LibraryQuery(section: selectedTab.section, collectionID: selectedCollectionID,
                                 tag: selectedTag, sort: sort).apply(to: snapshot)
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(280))
                let matches = try await searchService.search(needle, books: books)
                try Task.checkCancellation()
                passages = matches; isSearching = false
            } catch is CancellationError { /* Replaced by a newer query. */ }
            catch { isSearching = false; errorMessage = error.localizedDescription }
        }
    }
}
