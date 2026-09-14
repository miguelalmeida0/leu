import Foundation
import CryptoKit
import ShelfCore

/// The exact selection plus the smallest neighbouring spans needed to resolve a
/// reference. Every span carries a stable ID so a block can point back at what it used.
///
/// This is feature-local on purpose: `LearningSourcePacket` belongs to V26 and is shaped
/// for question generation. Nothing here mutates or replaces it.
struct ExplanationSourcePacket: Codable, Equatable, Sendable {
    struct Span: Codable, Equatable, Sendable {
        enum Role: String, Codable, Sendable {
            case selection
            case heading
            case precedingContext
            case followingContext
        }
        var id: String
        var role: Role
        var text: String
    }

    var documentID: UUID
    var fingerprint: String
    var extractionVersion: Int
    var pageIndex: Int
    var sourceRange: SourceTextRange
    /// Host-supplied display label, e.g. "React Notes · p. 18". Never invented here.
    var pageLabel: String
    var spans: [Span]
    var language: String

    var selectionText: String {
        spans.first(where: { $0.role == .selection })?.text ?? ""
    }

    var allowedSpanIDs: Set<String> { Set(spans.map(\.id)) }

    /// Full source text handed to the provider, span-labelled so the model can reference
    /// spans without being told to invent identifiers.
    var promptBody: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(spans)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    /// Binds the cache entry to everything that can change the correct answer.
    func cacheKey(mode: ExplanationMode, backend: String, providerRevision: String?) -> String {
        let context = spans.map { $0.id + "|" + $0.role.rawValue + "|" + $0.text }.joined(separator: "\u{1F}")
        let contextHash = SHA256.hash(data: Data(context.utf8)).map { String(format: "%02x", $0) }.joined()
        return [documentID.uuidString, fingerprint, String(extractionVersion), String(pageIndex),
                "\(sourceRange.location):\(sourceRange.length)", contextHash, language, mode.cacheToken, "schema\(ExplanationSchema.version)",
                "validator\(ExplanationSchema.validatorVersion)", backend,
                providerRevision ?? "revision-unknown"].joined(separator: "|")
    }
}

/// Builds a packet from a host selection. Returns nil rather than guessing when the
/// source is too short, too long or visibly damaged.
struct ExplanationPacketBuilder {
    static let minimumSelectionCharacters = 40
    static let maximumSpanCharacters = 2_400

    func packet(selection: LearningSource, pageLabel: String, fingerprint: String,
                extractionVersion: Int, canonicalPage: String, heading: String? = nil,
                preceding: String? = nil, following: String? = nil,
                language: String = "en") -> ExplanationSourcePacket? {
        let proposed = selection.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !proposed.contains("\u{FFFD}"), !canonicalPage.contains("\u{FFFD}"),
              extractionVersion >= SourceExtractionVersion.current, !fingerprint.isEmpty,
              let range = exactRange(selection, proposed: proposed, canonical: canonicalPage) else { return nil }
        let selected = (canonicalPage as NSString).substring(with: range)
        guard selected.utf16.count >= Self.minimumSelectionCharacters,
              selected.utf16.count <= Self.maximumSpanCharacters else { return nil }

        var spans: [ExplanationSourcePacket.Span] = [
            .init(id: "s1", role: .selection, text: selected)
        ]
        // Neighbouring spans are added only when they carry something, and only enough
        // to resolve a reference. This is not whole-page context.
        if let heading = anchored(heading, in: canonicalPage) {
            spans.append(.init(id: "h1", role: .heading, text: heading))
        }
        if let preceding = anchored(preceding, in: canonicalPage), needsReferenceResolution(selected) {
            spans.append(.init(id: "p1", role: .precedingContext, text: String(preceding.suffix(600))))
        }
        if let following = anchored(following, in: canonicalPage), selected.hasSuffix(":") {
            spans.append(.init(id: "f1", role: .followingContext, text: String(following.prefix(400))))
        }
        let total = spans.reduce(0) { $0 + $1.text.utf16.count }
        guard total <= Self.maximumSpanCharacters else { return nil }
        return ExplanationSourcePacket(documentID: selection.documentID, fingerprint: fingerprint,
                                       extractionVersion: extractionVersion,
                                       pageIndex: selection.pageIndex,
                                       sourceRange: SourceTextRange(location: range.location, length: range.length), pageLabel: pageLabel,
                                       spans: spans, language: language)
    }

    /// An unresolved opening reference is the one case worth pulling prior text for.
    private func needsReferenceResolution(_ text: String) -> Bool {
        let head = text.lowercased().split(whereSeparator: { !$0.isLetter }).first.map(String.init) ?? ""
        return ["it", "this", "that", "these", "those", "they", "such", "here"].contains(head)
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private func anchored(_ value: String?, in canonical: String) -> String? {
        guard let text = trimmed(value), let range = SourcePassageMatcher.range(of: text, in: canonical) else { return nil }
        return (canonical as NSString).substring(with: range)
    }

    private func exactRange(_ source: LearningSource, proposed: String, canonical: String) -> NSRange? {
        let page = canonical as NSString
        if let stored = source.range, stored.location >= 0, stored.length >= 0, stored.location <= page.length,
           stored.length <= page.length - stored.location {
            let range = NSRange(location: stored.location, length: stored.length)
            if page.substring(with: range).filter({ !$0.isWhitespace }) == proposed.filter({ !$0.isWhitespace }) { return range }
        }
        return SourcePassageMatcher.range(of: proposed, in: canonical)
    }
}
