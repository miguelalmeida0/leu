import Foundation

struct ReadingAnchor: Codable, Equatable {
    var pageIndex: Int
    var sentence: String?
    var updatedAt: Date

    init(pageIndex: Int, sentence: String? = nil, updatedAt: Date = Date()) {
        self.pageIndex = pageIndex
        self.sentence = sentence
        self.updatedAt = updatedAt
    }
}

final class ReadingAnchorStore {
    private let defaults: UserDefaults
    private let key: String

    init(bookID: UUID, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.key = "reader.anchor.\(bookID.uuidString)"
    }

    func load() -> ReadingAnchor? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ReadingAnchor.self, from: data)
    }

    func save(_ anchor: ReadingAnchor) {
        guard let data = try? JSONEncoder().encode(anchor) else { return }
        defaults.set(data, forKey: key)
    }
}
