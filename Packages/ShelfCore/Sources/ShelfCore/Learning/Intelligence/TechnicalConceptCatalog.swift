import Foundation

/// These families prohibit ambiguous distractors. Membership means related
/// mechanisms, NOT semantic identity, equivalence, or a proved factual edge.
public enum TechnicalConceptCatalog {
    public static func titleKey(_ text: String) -> String {
        CanonicalWhitespaceResolver.normalize(text).lowercased()
    }
    public static func overlapsForQuestion(_ a: String, _ b: String) -> Bool {
        let a = titleKey(a), b = titleKey(b)
        return a == b || ambiguousAlternativeFamilies.contains { $0.contains(a) && $0.contains(b) }
    }
    static func questionExclusions(_ title: String) -> Set<String> {
        let key = titleKey(title)
        return ambiguousAlternativeFamilies.filter { $0.contains(key) }.reduce(into: Set([key])) { $0.formUnion($1) }
    }
    private static let ambiguousAlternativeFamilies: [Set<String>] = [
        ["client-side routing", "routing", "spa", "history api", "single page application"],
        ["message queue", "queue", "worker", "background job", "backpressure", "task queue"],
        ["docker", "docker container", "docker image", "container", "container image"],
        ["type guard", "type narrowing", "narrowing", "runtime validation", "runtime validation vs static types"],
        ["grounding", "rag", "retrieval-augmented generation", "citation", "retrieval context", "source attribution"],
        ["contract test", "integration test", "unit test", "end-to-end test", "api test", "mock", "ai evaluation (eval)", "regression test", "dependency injection"],
        ["event bubbling", "event delegation", "event propagation", "event capturing"],
        ["lifting state up", "state colocation", "compound component", "shared state", "context"],
        ["tree shaking", "bundler", "dead code elimination", "minification", "code splitting"],
        ["single responsibility principle", "cohesion", "separation of concerns"],
        ["distributed cache", "shared cache", "cache replication"],
        ["write-through cache", "write-behind cache", "write-around cache", "cache invalidation", "cache-aside", "cache validation"],
        ["denormalization", "database index", "index", "materialized view", "precomputation", "memoization"],
        ["immutability", "array.map", "array.filter", "spread operator", "shallow copy", "deep copy", "immutable update"]
    ]
}
