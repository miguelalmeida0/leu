import Foundation

public struct IndexedPage: Codable, Equatable, Sendable {
    public var pageIndex: Int
    public var text: String
    public init(pageIndex: Int, text: String) { self.pageIndex = pageIndex; self.text = text }
}

public struct BookTextIndex: Codable, Equatable, Sendable {
    public var pages: [IndexedPage]
    public init(pages: [IndexedPage] = []) { self.pages = pages }
}

public protocol TextIndexPersistence: Sendable {
    func read(id: UUID) throws -> BookTextIndex?
    func write(_ index: BookTextIndex, id: UUID) throws
    func remove(id: UUID) throws
}
