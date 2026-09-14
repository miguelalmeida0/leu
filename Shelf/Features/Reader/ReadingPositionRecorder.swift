import Foundation
import ShelfCore

/// Coalesces viewport writes. Closing/backgrounding explicitly flushes the latest position.
@MainActor
final class ReadingPositionRecorder {
    private let repository: LibraryRepository
    private let bookID: UUID
    private var task: Task<Void, Never>?
    private var pending: ReadingPosition?
    var onError: ((String) -> Void)?
    init(repository: LibraryRepository, bookID: UUID) { self.repository = repository; self.bookID = bookID }
    func schedule(_ position: ReadingPosition) {
        pending = position
        task?.cancel()
        task = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch { return }
            guard let self, !Task.isCancelled else { return }
            do { try await self.flush() } catch { self.onError?(error.localizedDescription) }
        }
    }
    func flush() async throws {
        task?.cancel(); task = nil
        guard let position = pending else { return }
        // Keep pending data on failure so a subsequent flush can retry.
        try await repository.savePosition(bookID: bookID, position: position)
        if pending == position { pending = nil }
    }
}
