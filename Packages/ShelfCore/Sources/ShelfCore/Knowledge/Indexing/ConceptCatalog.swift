import Foundation

public struct ConceptCatalog: Sendable {
    public struct Seed: Sendable {
        public var name: String
        public var aliases: [String]
        public var parent: String?
        public var pack: String
        public init(_ name: String, _ aliases: [String] = [], parent: String? = nil, pack: String) {
            self.name = name; self.aliases = aliases; self.parent = parent; self.pack = pack
        }
    }

    public static let seeds: [Seed] = [
        Seed("React", ["react.js"], pack: "React"),
        Seed("Reconciliation", ["react reconciliation"], parent: "React", pack: "React"),
        Seed("Component Identity", ["component identity", "stable identity"], parent: "Reconciliation", pack: "React"),
        Seed("Keys", ["react keys", "stable keys", "key prop"], parent: "Component Identity", pack: "React"),
        Seed("State Preservation", ["preserving state", "state preservation"], parent: "Component Identity", pack: "React"),
        Seed("Virtual DOM", ["virtual dom", "vdom"], parent: "Reconciliation", pack: "React"),
        Seed("Memoization", ["memoization", "react.memo", "usememo", "use memo"], parent: "React", pack: "React"),
        Seed("Referential Equality", ["referential equality", "reference equality"], parent: "Memoization", pack: "React"),
        Seed("Effects", ["useeffect", "use effect", "effect cleanup", "dependency array"], parent: "React", pack: "React"),
        Seed("JavaScript", ["javascript", "ecmascript", "js"], pack: "JavaScript"),
        Seed("Closures", ["closure", "closures"], parent: "JavaScript", pack: "JavaScript"),
        Seed("Lexical Scope", ["lexical scope", "lexical environment"], parent: "Closures", pack: "JavaScript"),
        Seed("Event Loop", ["event loop"], parent: "JavaScript", pack: "JavaScript"),
        Seed("Task Queue", ["task queue", "macrotask queue"], parent: "Event Loop", pack: "JavaScript"),
        Seed("Microtask Queue", ["microtask queue", "microtasks"], parent: "Event Loop", pack: "JavaScript"),
        Seed("Promises", ["promise", "promises", "promise.all", "promise.resolve"], parent: "Event Loop", pack: "JavaScript"),
        Seed("requestAnimationFrame", ["requestanimationframe", "raf"], parent: "Event Loop", pack: "Frontend"),
        Seed("Browser Rendering", ["browser rendering", "rendering pipeline", "critical rendering path"], pack: "Frontend"),
        Seed("DOM", ["dom", "document object model"], parent: "Browser Rendering", pack: "Frontend"),
        Seed("Accessibility", ["accessibility", "a11y", "aria", "aria-label"], pack: "Frontend"),
        Seed("HTTP", ["http", "http/2", "https"], pack: "Networking"),
        Seed("HTTP Caching", ["http caching", "browser cache", "cache-control", "etag"], parent: "HTTP", pack: "Networking"),
        Seed("REST", ["rest", "rest api", "restful"], parent: "HTTP", pack: "Backend"),
        Seed("Authentication", ["authentication", "session-based authentication", "jwt", "oauth"], pack: "Backend"),
        Seed("Database Transactions", ["database transaction", "transactions", "acid", "isolation level"], pack: "Backend"),
        Seed("PostgreSQL", ["postgresql", "postgres", "mvcc"], parent: "Database Transactions", pack: "Backend"),
        Seed("TypeScript", ["typescript", "type script"], pack: "TypeScript"),
        Seed("Structural Typing", ["structural typing", "structural type system"], parent: "TypeScript", pack: "TypeScript"),
        Seed("Generics", ["generics", "generic type", "type parameter"], parent: "TypeScript", pack: "TypeScript"),
        Seed("Algorithms", ["algorithm", "algorithms"], pack: "Computer Science"),
        Seed("Big O", ["big o", "o(n)", "o(log n)", "time complexity", "space complexity"], parent: "Algorithms", pack: "Computer Science"),
        Seed("Binary Search", ["binary search"], parent: "Algorithms", pack: "Computer Science"),
        Seed("Data Structures", ["data structure", "data structures"], pack: "Computer Science"),
        Seed("Testing", ["unit test", "integration test", "e2e", "playwright", "xctest"], pack: "Engineering"),
        Seed("Git", ["git", "rebase", "merge", "commit"], pack: "Engineering")
    ]

    public static func seeded() -> (concepts: [KnowledgeConcept], aliases: [ConceptAlias]) {
        let conceptIDs = Dictionary(uniqueKeysWithValues: seeds.map { seed in
            (seed.name, StableIdentity.uuid("knowledge-concept|" + seed.name.lowercased()))
        })
        var concepts: [KnowledgeConcept] = []
        var aliases: [ConceptAlias] = []
        for seed in seeds {
            guard let id = conceptIDs[seed.name] else { continue }
            concepts.append(KnowledgeConcept(id: id, name: seed.name,
                parentID: seed.parent.flatMap { conceptIDs[$0] }, pack: seed.pack))
            for value in [seed.name] + seed.aliases {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
                aliases.append(ConceptAlias(id: StableIdentity.uuid("knowledge-alias|\(id)|\(normalized.lowercased())"),
                                            conceptID: id, value: normalized))
            }
        }
        return (concepts, aliases)
    }
}
