import Foundation

public protocol DocumentVault: Sendable {
    func originalURL(for id: UUID) -> URL
    func stageCopy(from source: URL, id: UUID) throws -> URL
    func removeOriginal(id: UUID) throws
    func contains(id: UUID) -> Bool
}

public struct PDFInspection: Sendable {
    public var pageCount: Int
    public var index: BookTextIndex
    public var status: TextIndexStatus
    public init(pageCount: Int, index: BookTextIndex, status: TextIndexStatus) {
        self.pageCount = pageCount; self.index = index; self.status = status
    }
}

public protocol DocumentInspecting: Sendable {
    /// Use an independent PDF instance. Do not share a live reader document across threads.
    func inspect(_ url: URL) async throws -> PDFInspection
}
