import Foundation
import ShelfCore

extension ReaderModel {
    func search() {
        searchTask?.cancel(); searchResults = []
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { isSearching = false; return }
        isSearching = true
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(250))
                let results = try await searchService.search(url: url, query: query, bookID: book.id)
                try Task.checkCancellation()
                searchResults = results; isSearching = false
            } catch is CancellationError { /* A newer query owns presentation now. */ }
            catch { isSearching = false; errorMessage = error.localizedDescription }
        }
    }


    func openSearchResult(_ match: PassageMatch) {
        let origin = pageIndex
        if origin != match.pageIndex { searchReturnPage = origin }
        go(to: match.pageIndex)
        if displayMode == .original { controller.find(match) }
        savedMessage = "Match on page \(match.pageIndex + 1)"
    }

    func returnToSearchOrigin() {
        guard let origin = searchReturnPage else { return }
        searchReturnPage = nil
        savedMessage = nil
        go(to: origin)
    }
}
