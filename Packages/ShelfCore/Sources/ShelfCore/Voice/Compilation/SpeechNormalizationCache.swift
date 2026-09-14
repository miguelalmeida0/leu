import Foundation

/// A bounded, compilation-local memo. It stores spoken text only, never source mappings.
/// Dictionary and code mode are fixed for a single compile call; no cache survives that call.
struct SpeechNormalizationCache {
    struct Key: Hashable { let source: String; let isCode: Bool }
    static let maximumEntries = 256
    static let maximumEntryBytes = 4_096
    private var values: [Key: String] = [:]
    var count: Int { values.count }

    mutating func value(for source: String, isCode: Bool, normalize: () -> String) -> String {
        let key = Key(source: source, isCode: isCode)
        if let cached = values[key] { return cached }
        let spoken = normalize()
        if values.count < Self.maximumEntries,
           source.utf8.count + spoken.utf8.count <= Self.maximumEntryBytes {
            values[key] = spoken
        }
        return spoken
    }
}
