import Foundation

public struct BookCollection: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var order: Int
    public init(id: UUID = UUID(), name: String, order: Int = 0) {
        self.id = id
        self.name = name
        self.order = order
    }
}

public struct PageBookmark: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var bookID: UUID
    public var pageIndex: Int
    public var title: String
    public var createdAt: Date
    public init(id: UUID = UUID(), bookID: UUID, pageIndex: Int,
                title: String, createdAt: Date = Date()) {
        self.id = id
        self.bookID = bookID
        self.pageIndex = pageIndex
        self.title = title
        self.createdAt = createdAt
    }
}
