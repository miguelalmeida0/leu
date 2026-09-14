import Foundation

public struct PronunciationEntry: Identifiable, Codable, Equatable, Hashable, Sendable {
    public enum Origin: String, Codable, Sendable { case system, user }
    public var id: UUID
    public var display: String
    public var spoken: String
    public var origin: Origin

    public init(id: UUID = UUID(), display: String, spoken: String, origin: Origin) {
        self.id = id; self.display = display; self.spoken = spoken; self.origin = origin
    }
}

public struct PronunciationDictionary: Sendable {
    public var systemEntries: [PronunciationEntry]
    public var userEntries: [PronunciationEntry]

    public init(systemEntries: [PronunciationEntry] = Self.defaults, userEntries: [PronunciationEntry] = []) {
        self.systemEntries = systemEntries; self.userEntries = userEntries
    }

    public func spokenForm(for token: String) -> String? {
        let compare: (PronunciationEntry) -> Bool = { $0.display.compare(token, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        return userEntries.first(where: compare)?.spoken ?? systemEntries.first(where: compare)?.spoken
    }

    public mutating func setUserOverride(display: String, spoken: String) {
        userEntries.removeAll { $0.display.compare(display, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        userEntries.append(PronunciationEntry(display: display, spoken: spoken, origin: .user))
    }

    public static let defaults: [PronunciationEntry] = [
        .init(display: "useEffect", spoken: "use effect", origin: .system),
        .init(display: "useState", spoken: "use state", origin: .system),
        .init(display: "useMemo", spoken: "use memo", origin: .system),
        .init(display: "useCallback", spoken: "use callback", origin: .system),
        .init(display: "useReducer", spoken: "use reducer", origin: .system),
        .init(display: "TypeScript", spoken: "Type Script", origin: .system),
        .init(display: "JavaScript", spoken: "Java Script", origin: .system),
        .init(display: "SvelteKit", spoken: "Svelte Kit", origin: .system),
        .init(display: "WebSocket", spoken: "Web Socket", origin: .system),
        .init(display: "PostgreSQL", spoken: "Postgres Q L", origin: .system),
        .init(display: "Node.js", spoken: "Node J S", origin: .system),
        .init(display: "Next.js", spoken: "Next J S", origin: .system),
        .init(display: "React.memo", spoken: "React dot memo", origin: .system),
        .init(display: "Promise.all", spoken: "promise dot all", origin: .system),
        .init(display: "Promise.all()", spoken: "promise dot all", origin: .system),
        .init(display: "Promise.resolve", spoken: "promise dot resolve", origin: .system),
        .init(display: "console.log", spoken: "console dot log", origin: .system),
        .init(display: "console.log()", spoken: "console dot log", origin: .system),
        .init(display: "Array.map", spoken: "array dot map", origin: .system),
        .init(display: "Array.map()", spoken: "array dot map", origin: .system)
    ]
}
