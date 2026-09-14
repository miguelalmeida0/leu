import Foundation

public struct TopicClassification: Equatable, Sendable {
    public var topic: LearningTopic
    public var score: Double
    public init(topic: LearningTopic, score: Double) { self.topic = topic; self.score = score }
}

public struct TopicClassifier: Sendable {
    public struct Seed: Sendable {
        public var topic: LearningTopic
        public var vocabulary: Set<String>
        public init(topic: LearningTopic, vocabulary: Set<String>) {
            self.topic = topic; self.vocabulary = vocabulary
        }
    }

    public let seeds: [Seed]

    public init(seeds: [Seed] = TopicClassifier.defaultSeeds) { self.seeds = seeds }

    public func classify(title: String, filename: String, outline: [String], text: String) -> [TopicClassification] {
        classify(title: title, filename: filename, outline: outline, texts: [text])
    }

    public func classify(title: String, filename: String, outline: [String], texts: [String]) -> [TopicClassification] {
        let titleTokens = tokens(title + " " + filename)
        let outlineTokens = tokens(outline.joined(separator: " "))
        var bodyCounts: [String: Int] = [:]
        var total = 0
        for text in texts {
            let pageTokens = tokenList(text)
            total += pageTokens.count
            for token in pageTokens { bodyCounts[token, default: 0] += 1 }
        }
        let safeTotal = max(1, total)

        return seeds.compactMap { seed in
            let titleHits = seed.vocabulary.intersection(titleTokens).count
            let outlineHits = seed.vocabulary.intersection(outlineTokens).count
            let weightedBody = seed.vocabulary.reduce(0.0) { result, term in
                let count = bodyCounts[term, default: 0]
                guard count > 0 else { return result }
                return result + min(3.0, 1.0 + log(Double(count)))
            }
            let density = weightedBody / sqrt(Double(safeTotal))
            let raw = Double(titleHits) * 2.5 + Double(outlineHits) * 1.6 + density
            guard raw >= 0.85 else { return nil }
            return TopicClassification(topic: seed.topic, score: min(1, raw / 6.0))
        }
        .sorted { lhs, rhs in lhs.score == rhs.score ? lhs.topic.name < rhs.topic.name : lhs.score > rhs.score }
    }

    private func tokens(_ text: String) -> Set<String> { Set(tokenList(text)) }

    private func tokenList(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber && $0 != "+" && $0 != "#" }
            .map(String.init).filter { $0.count > 1 }
    }

    private func counts(_ tokens: [String]) -> [String: Int] {
        tokens.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }

    public static let defaultSeeds: [Seed] = [
        seed("Frontend", ["html","css","browser","dom","rendering","accessibility","javascript","event","state","performance","network","component","ui","web","layout","paint","reflow"]),
        seed("Backend", ["api","http","database","cache","server","authentication","authorization","queue","microservice","sql","transaction","distributed","backend","endpoint","session","cookie"]),
        seed("React", ["react","component","hook","state","effect","reconciliation","jsx","props","render","context","memo","key","usestate","useeffect"]),
        seed("TypeScript", ["typescript","type","interface","generic","union","intersection","enum","typing","inference","keyof","conditional","readonly","unknown","never"]),
        seed("System Design", ["scalability","availability","latency","throughput","load","balancer","replication","sharding","consistency","distributed","architecture","capacity"]),
        seed("Networking", ["tcp","udp","dns","http","tls","socket","network","packet","latency","bandwidth","request","response"]),
        seed("JavaScript", ["javascript","closure","promise","microtask","event","loop","prototype","async","await","scope","hoisting","iterator"])
    ]

    private static func seed(_ name: String, _ terms: [String]) -> Seed {
        Seed(topic: LearningTopic(id: StableIdentity.uuid("topic|" + name.lowercased()), name: name), vocabulary: Set(terms))
    }
}
