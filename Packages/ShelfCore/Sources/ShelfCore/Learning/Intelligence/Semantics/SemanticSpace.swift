import Foundation

/// A static semantic space for single words: WordPiece vectors distilled from
/// sentence-transformers/all-MiniLM-L6-v2 (Apache-2.0), reduced to 256 dimensions and quantized
/// to int8 with one global scale (`scripts/build-semantic-space.py`). A word's vector is the sum of
/// its pieces' vectors and every similarity is an exact integer dot product, so the same two words
/// compare identically on every device. No model runs: this is a lookup table.
///
/// Evidence only. A similarity says two words tend to occur in similar contexts — which also holds
/// for opposites ("fast" is closer to "slow" than "retain" is to "keep"). It never decides anything
/// on its own; the reader decides with it (`SemanticMatcher`, `SemanticThresholds`).
final class SemanticSpace: @unchecked Sendable {
    static let resource = "minilm-static-256"
    /// SHA-256 of the resource as built; tests check the bundled file is this one.
    static let digest = "c671216771e7d98c6bb20249ed30dc9e6a41141ea3a29fd11b9e4e7964f99c6b"

    /// A word's vector: the integer sum of its pieces, with its squared length.
    struct Vector: Sendable {
        let values: [Int32]
        let squaredLength: Int64
    }

    let dimensions: Int
    private let vocabulary: [String: Int32]
    private let table: [Int8]
    private let lock = NSLock()
    /// Word vectors never change, so they are kept once computed: at most 8 192 of them (about
    /// 9 MB of 256 Int32 each), dropped all at once when full.
    private var cache: [String: Vector?] = [:]
    private static let cacheLimit = 8_192

    /// The bundled space, or nil when the resource is missing or malformed — the reader then
    /// reads exactly as it did without it.
    static let shared: SemanticSpace? = Bundle.module
        .url(forResource: resource, withExtension: "leusem", subdirectory: "SemanticSpace")
        .flatMap { try? Data(contentsOf: $0, options: .alwaysMapped) }
        .flatMap(SemanticSpace.init(data:))

    /// Layout (little-endian): "LEUSEM01", UInt32 version, UInt32 dimensions, UInt32 count,
    /// Float32 scale, UInt32 vocabulary bytes, the vocabulary ("\n"-separated UTF-8), then
    /// count × dimensions Int8.
    init?(data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count > 28, bytes.prefix(8) == ArraySlice(Array("LEUSEM01".utf8)) else { return nil }
        func uint32(_ offset: Int) -> Int {
            Int(UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24)
        }
        let version = uint32(8), dimensions = uint32(12), count = uint32(16), vocabularyBytes = uint32(24)
        let start = 28 + vocabularyBytes
        guard version == 1, dimensions > 0, count > 0, bytes.count == start + count * dimensions,
              let words = String(bytes: bytes[28..<start], encoding: .utf8)?.components(separatedBy: "\n"), words.count == count
        else { return nil }
        self.dimensions = dimensions
        var vocabulary: [String: Int32] = [:]
        vocabulary.reserveCapacity(count)
        for (index, word) in words.enumerated() where vocabulary[word] == nil { vocabulary[word] = Int32(index) }
        self.vocabulary = vocabulary
        table = bytes[start...].map { Int8(bitPattern: $0) }
    }

    /// BERT (uncased) WordPiece for one word: lowercase, accents removed, greedy longest match
    /// first, continuation pieces prefixed "##". Nil when any part is unknown.
    func pieces(_ word: String) -> [Int32]? {
        let characters = Array(word.lowercased().folding(options: .diacriticInsensitive, locale: nil))
        guard !characters.isEmpty, characters.count <= 100 else { return nil }
        var result: [Int32] = [], start = 0
        while start < characters.count {
            var end = characters.count, found: Int32?
            while start < end {
                if let id = vocabulary[(start > 0 ? "##" : "") + String(characters[start..<end])] { found = id; break }
                end -= 1
            }
            guard let id = found else { return nil }
            result.append(id)
            start = end
        }
        return result
    }

    /// The vector of a word as the reader sees it ("one_way", "set-state": the sum of its parts).
    func vector(_ word: String) -> Vector? {
        lock.lock()
        if let known = cache[word] { lock.unlock(); return known }
        lock.unlock()
        let parts = word.split { !$0.isLetter && !$0.isNumber }.compactMap { pieces(String($0)) }
        var values = [Int32](repeating: 0, count: dimensions)
        for id in parts.joined() {
            let row = Int(id) * dimensions
            for index in 0..<dimensions { values[index] += Int32(table[row + index]) }
        }
        let squared = values.reduce(Int64(0)) { $0 + Int64($1) * Int64($1) }
        let result = parts.isEmpty || squared == 0 ? nil : Vector(values: values, squaredLength: squared)
        lock.lock()
        if cache.count >= Self.cacheLimit { cache.removeAll(keepingCapacity: true) }
        cache[word] = result
        lock.unlock()
        return result
    }

    /// Cosine of two word vectors, from an exact integer dot product.
    static func similarity(_ a: Vector, _ b: Vector) -> Double {
        var dot: Int64 = 0
        for index in a.values.indices { dot += Int64(a.values[index]) * Int64(b.values[index]) }
        return Double(dot) / (Double(a.squaredLength).squareRoot() * Double(b.squaredLength).squareRoot())
    }

    func similarity(_ a: String, _ b: String) -> Double? {
        guard let x = vector(a), let y = vector(b) else { return nil }
        return Self.similarity(x, y)
    }
}
