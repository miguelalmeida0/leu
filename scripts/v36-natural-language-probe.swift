// V36 Phase 1: does Apple's NaturalLanguage framework read the V36 adversarial pairs well enough to
// be Leu's semantic evidence? Run on a Mac: `swift scripts/v36-natural-language-probe.swift`.
// It prints, for word and sentence NLEmbedding (and NLContextualEmbedding where the OS has it),
// the distance of each pair and the time taken. It never downloads assets on its own: contextual
// embedding assets are reported as missing rather than requested.
import Foundation
import NaturalLanguage

/// (a, b, should they read as the same meaning?)
let pairs: [(String, String, Bool)] = [
    ("A closure remembers its surrounding bindings.",
     "The inner function can still access variables from the function that created it.", true),
    ("Authentication establishes identity.", "Authentication does not establish identity.", false),
    ("JWTs are signed, not encrypted: anyone can read the payload.", "JWTs are signed so nobody can read them.", false),
    ("An index makes particular lookups faster.", "An index makes particular lookups slower.", false),
    ("A refresh token is used to obtain new access tokens.", "An access token is used to obtain new refresh tokens.", false),
    ("Retry when the failure may be temporary.", "Always retry every failed call.", false),
    ("Idempotency means repeating an operation has the same effect as doing it once.",
     "Pressing the lift button five times still brings one lift.", true),
    ("Throttling runs a handler at most once per time window.", "The handler fires no more than once in each interval.", true),
]
let words: [(String, String)] = [("retain", "keep"), ("fast", "slow"), ("increase", "decrease"), ("bindings", "variables"),
                                  ("verify", "prove"), ("encrypted", "signed")]

func timed<T>(_ body: () throws -> T) rethrows -> (T, Double) {
    let start = DispatchTime.now().uptimeNanoseconds
    let value = try body()
    return (value, Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
}

print("OS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
let (wordEmbedding, wordLoadMS) = timed { NLEmbedding.wordEmbedding(for: .english) }
if let word = wordEmbedding {
    print("word embedding: dimension=\(word.dimension) revision=\(word.revision) load=\(String(format: "%.1f", wordLoadMS)) ms")
    for (a, b) in words {
        let (distance, ms) = timed { word.distance(between: a, and: b) }
        print("  word \(a)/\(b): cosine distance \(String(format: "%.3f", distance)) (\(String(format: "%.3f", ms)) ms)")
    }
} else { print("word embedding: unavailable") }

let (sentenceEmbedding, sentenceLoadMS) = timed { NLEmbedding.sentenceEmbedding(for: .english) }
if let sentence = sentenceEmbedding {
    print("sentence embedding: dimension=\(sentence.dimension) revision=\(sentence.revision) load=\(String(format: "%.1f", sentenceLoadMS)) ms")
    for (a, b, same) in pairs {
        let (distance, ms) = timed { sentence.distance(between: a, and: b) }
        print("  [\(same ? "same" : "DIFFERENT")] \(String(format: "%.3f", distance)) (\(String(format: "%.2f", ms)) ms) :: \(a) || \(b)")
    }
} else { print("sentence embedding: unavailable") }

if #available(macOS 14.0, iOS 17.0, *) {
    if let contextual = NLContextualEmbedding(language: .english) {
        print("contextual embedding: dimension=\(contextual.dimension) hasAvailableAssets=\(contextual.hasAvailableAssets)")
        if contextual.hasAvailableAssets {
            do {
                try contextual.load()
                for (a, b, same) in pairs {
                    func mean(_ text: String) throws -> [Double] {
                        let result = try contextual.embeddingResult(for: text, language: .english)
                        var sum = [Double](repeating: 0, count: contextual.dimension), count = 0.0
                        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, _ in
                            for index in vector.indices { sum[index] += vector[index] }
                            count += 1
                            return true
                        }
                        return sum.map { $0 / max(count, 1) }
                    }
                    let ((va, vb), ms) = try timed { (try mean(a), try mean(b)) }
                    let dot = zip(va, vb).reduce(0) { $0 + $1.0 * $1.1 }
                    let norm = sqrt(va.reduce(0) { $0 + $1 * $1 }) * sqrt(vb.reduce(0) { $0 + $1 * $1 })
                    print("  [\(same ? "same" : "DIFFERENT")] cosine \(String(format: "%.3f", norm > 0 ? dot / norm : 0)) (\(String(format: "%.1f", ms)) ms)")
                }
            } catch { print("contextual embedding: load failed \(error)") }
        }
    } else { print("contextual embedding: unavailable for English") }
} else { print("contextual embedding: needs macOS 14 / iOS 17") }
