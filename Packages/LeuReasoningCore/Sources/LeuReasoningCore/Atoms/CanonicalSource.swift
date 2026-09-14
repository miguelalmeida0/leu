import Foundation

/// The certification bridge supplies unedited PDFKit page strings. Offsets below
/// are UTF-16 offsets into these strings, never into reconstructed prose.
public struct CanonicalDocument: Codable, Sendable {
    public struct Page: Codable, Sendable { public var number: Int; public var text: String }
    public var id: String
    public var title: String
    public var sha256: String
    public var pages: [Page]
}

public struct FactualPacket: Codable, Sendable {
    public var title: String
    public var titleSpan: SourceSpan
    public var body: SourceSpan
    public init(title: String, titleSpan: SourceSpan, body: SourceSpan) {
        self.title = title; self.titleSpan = titleSpan; self.body = body
    }
}

public struct PacketExtraction: Codable, Sendable {
    public var packet: FactualPacket
    public var atoms: [KnowledgeAtom]
    public var unresolved: [String]
}

public enum CanonicalSource {
    public static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Headings, not vocabulary in the body, delimit factual authority. Neither
    /// advice nor an example is promoted to an unconditional factual claim.
    public static func card(in page: CanonicalDocument.Page, documentID: String) -> FactualPacket? {
        let text = page.text as NSString
        var lines: [(String, NSRange)] = []
        var offset = 0
        for line in page.text.components(separatedBy: "\n") {
            lines.append((line, NSRange(location: offset, length: (line as NSString).length)))
            offset += (line as NSString).length + 1
        }
        func heading(_ s: String) -> String { s.filter(\.isLetter).uppercased() }
        guard let start = lines.firstIndex(where: { heading($0.0) == "INONEBREATH" }), start >= 1,
              let end = lines.indices.dropFirst(start + 1).first(where: { heading(lines[$0].0) == "MAKEITSTICK" }), end > start + 1 else { return nil }
        // Card number and category occupy the first two lines. Titles may wrap.
        let titleStart = min(2, start - 1)
        let titleRange = NSRange(location: lines[titleStart].1.location,
                                length: lines[start - 1].1.location + lines[start - 1].1.length - lines[titleStart].1.location)
        let bodyRange = NSRange(location: lines[start + 1].1.location,
                               length: lines[end - 1].1.location + lines[end - 1].1.length - lines[start + 1].1.location)
        func span(_ range: NSRange, _ role: SourceRole) -> SourceSpan {
            SourceSpan(documentID: documentID, page: page.number, canonicalSpan: text.substring(with: range),
                       characterOffset: range.location, sourceRole: role, extractionVersion: "leu.pdf-packet.1")
        }
        return FactualPacket(title: normalized(text.substring(with: titleRange)),
                             titleSpan: span(titleRange, .structure), body: span(bodyRange, .compactExplanation))
    }

    public static func verifies(_ span: SourceSpan, documents: [CanonicalDocument]) -> Bool {
        guard let page = documents.first(where: { $0.id == span.documentID })?.pages.first(where: { $0.number == span.page }),
              let offset = span.characterOffset, offset >= 0, !span.canonicalSpan.isEmpty else { return false }
        let text = page.text as NSString
        let range = NSRange(location: offset, length: (span.canonicalSpan as NSString).length)
        return NSMaxRange(range) <= text.length && text.substring(with: range) == span.canonicalSpan
    }

    /// The bundled notes use a running header and short title, prose, code and
    /// diagrams. Code/furniture end a prose packet; sentence boundaries preserve
    /// exact source substrings. Imperative study instructions are not facts.
    public static func noteSpans(in page: CanonicalDocument.Page, documentID: String) -> [SourceSpan] {
        let ns = page.text as NSString
        var offset = 0, buffer = "", start = 0, spans: [SourceSpan] = []
        func flush() {
            var cursor = 0
            for sentence in TextScanning.sentences(in: buffer) {
                let range = (buffer as NSString).range(of: sentence, range: NSRange(location: cursor, length: (buffer as NSString).length - cursor))
                guard range.location != NSNotFound else { continue }
                cursor = NSMaxRange(range)
                let normalized = normalized(sentence)
                let first = normalized.split(separator: " ").first?.lowercased() ?? ""
                guard sentence.hasSuffix("."), !["ask:", "practice:", "reading", "check", "close", "identify", "give", "keep", "decide", "before", "do", "a useful question:"].contains(first),
                      !normalized.contains("https://"), !normalized.contains("?") else { continue }
                let rangeInPage = NSRange(location: start + range.location, length: range.length)
                guard NSMaxRange(rangeInPage) <= ns.length else { continue }
                spans.append(SourceSpan(documentID: documentID, page: page.number, canonicalSpan: ns.substring(with: rangeInPage),
                                        characterOffset: rangeInPage.location, sourceRole: .explanation, extractionVersion: "leu.pdf-packet.1"))
            }
            buffer = ""
        }
        for (index, line) in page.text.components(separatedBy: "\n").enumerated() {
            defer { offset += (line as NSString).length + 1 }
            let code = line.contains("=>") || line.contains(";") || line.contains("{") || line.contains("}") || line.hasPrefix("//") || line.contains("//") || line.hasPrefix("<")
            let diagram = !line.contains(".") && line.split(separator: " ").count <= 4 && line.split(separator: " ").filter { $0.first?.isUppercase == true }.count >= 3
            if index < (page.number == 1 ? 3 : 2) || line.hasPrefix("SHELF /") || code || diagram {
                flush(); continue
            }
            if buffer.isEmpty { start = offset; buffer = line } else { buffer += "\n" + line }
        }
        flush()
        return spans
    }
}

/// Card-local grammatical completion. The title supplies only the explicit
/// card topic; it cannot supply missing predicates or consequences. Unrecognised
/// grammar stays unresolved. No previous card is kept in parser state.
public struct PacketAtomExtractor: Sendable {
    public init() {}
    private struct Verb { var word: String; var relation: String; var type: ClaimType }
    private static let verbs: [Verb] = [
        .init(word: "depends on", relation: "requires", type: .prerequisite),
        .init(word: "results in", relation: "causes", type: .cause),
        .init(word: "leads to", relation: "causes", type: .cause),
        .init(word: "enables", relation: "enables", type: .mechanism),
        .init(word: "allows", relation: "enables", type: .mechanism),
        .init(word: "lets", relation: "enables", type: .mechanism),
        .init(word: "helps", relation: "supports", type: .mechanism),
        .init(word: "supports", relation: "supports", type: .mechanism),
        .init(word: "prevents", relation: "prevents", type: .mechanism),
        .init(word: "avoids", relation: "prevents", type: .mechanism),
        .init(word: "requires", relation: "requires", type: .prerequisite),
        .init(word: "needs", relation: "requires", type: .prerequisite),
        .init(word: "causes", relation: "causes", type: .cause),
        // Distinct operators: reducing latency must never become causing latency.
        .init(word: "reduces", relation: "reduces", type: .consequence),
        .init(word: "increases", relation: "increases", type: .consequence),
        .init(word: "creates", relation: "creates", type: .mechanism),
        .init(word: "makes", relation: "makes", type: .mechanism),
        .init(word: "keeps", relation: "keeps", type: .mechanism),
        .init(word: "gives", relation: "gives", type: .mechanism),
        .init(word: "separates", relation: "separates", type: .mechanism),
        .init(word: "decouples", relation: "decouples", type: .mechanism),
        .init(word: "replaces", relation: "replaces", type: .mechanism),
        .init(word: "catches", relation: "catches", type: .mechanism),
        .init(word: "derives", relation: "derives", type: .mechanism),
        .init(word: "balances", relation: "balances", type: .tradeoff),
        .init(word: "trades", relation: "trades", type: .tradeoff),
        .init(word: "models", relation: "models", type: .definition),
        .init(word: "describes", relation: "explains", type: .definition),
        .init(word: "selects", relation: "selects", type: .mechanism),
        .init(word: "collects", relation: "collects", type: .mechanism),
        .init(word: "returns", relation: "returns", type: .mechanism),
        .init(word: "requests", relation: "requests", type: .mechanism),
        .init(word: "presents", relation: "presents", type: .mechanism),
        .init(word: "coordinates", relation: "coordinates", type: .mechanism),
        .init(word: "commits", relation: "commits", type: .mechanism),
        .init(word: "destroys", relation: "destroys", type: .failureMode),
        .init(word: "solves", relation: "solves", type: .mechanism),
        .init(word: "introduces", relation: "introduces", type: .consequence),
        .init(word: "updates", relation: "updates", type: .mechanism),
        .init(word: "smooths", relation: "smooths", type: .mechanism),
        .init(word: "communicates", relation: "communicates", type: .mechanism),
        .init(word: "computes", relation: "computes", type: .mechanism),
        .init(word: "centralizes", relation: "centralizes", type: .mechanism),
        .init(word: "improves", relation: "improves", type: .mechanism),
        .init(word: "verifies", relation: "verifies", type: .mechanism),
        .init(word: "be", relation: "explains", type: .definition),
        .init(word: "is", relation: "explains", type: .definition),
        .init(word: "are", relation: "explains", type: .definition)
    ]

    public func extractProse(_ span: SourceSpan) -> PacketExtraction {
        extract(FactualPacket(title: "", titleSpan: span, body: span), inheritsTitle: false)
    }

    public func extract(_ packet: FactualPacket, inheritsTitle: Bool = true) -> PacketExtraction {
        let sentences = TextScanning.sentences(in: packet.body.canonicalSpan)
        var atoms: [KnowledgeAtom] = [], unresolved: [String] = []
        var searchStart = 0
        var titleEstablished = false
        for (index, raw) in sentences.enumerated() {
            let body = packet.body.canonicalSpan as NSString
            let range = body.range(of: raw, range: NSRange(location: searchStart, length: body.length - searchStart))
            guard range.location != NSNotFound else { unresolved.append(raw); continue }
            searchStart = NSMaxRange(range)
            var span = packet.body
            span.canonicalSpan = raw
            span.characterOffset = (packet.body.characterOffset ?? 0) + range.location
            let sentence = CanonicalSource.normalized(raw).trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
            let words = sentence.split(separator: " ").map(String.init)
            guard !words.isEmpty else { continue }
            let leading = words[0].lowercased()
            var work = sentence
            var inherited = false
            if inheritsTitle && index == 0 && Self.verbs.contains(where: { $0.word == leading && !["is", "are", "be"].contains(leading) }) {
                // "Contract test: Verifies ..." is a finite predicate whose
                // subject is explicitly supplied by the card heading.
                work = packet.title + " " + sentence
                inherited = true
            }
            if ["it", "they"].contains(leading) {
                guard titleEstablished else { unresolved.append(raw); continue }
                work = packet.title + " " + words.dropFirst().joined(separator: " ")
                inherited = true
            } else if ["this", "that", "these", "those", "its", "their", "he", "she"].contains(leading) {
                unresolved.append(raw); continue
            }
            // The initial body fragment defines the card topic. Relative clauses
            // inside a noun phrase must not steal the topic's subject position.
            let fragment = index == 0 && ["a", "an", "the"].contains(leading)
            let actionFragment = index == 0 && (leading.hasSuffix("ing") || ["move", "constrain", "keep", "intentionally"].contains(leading))
            let nominalOpening = ["language", "standard", "inputs", "built-in", "reusable"].contains(leading)
            let noFiniteVerb = index == 0 && firstVerb(work) == nil && nominalOpening
            let relativeBeforeVerb: Bool = {
                guard index == 0, let verb = firstVerb(work) else { return false }
                let prefix = String(work[..<verb.1.lowerBound]).lowercased()
                return (leading.contains("-") || nominalOpening) && [" that ", " whose ", " where ", " when "].contains(where: prefix.contains)
            }()
            if inheritsTitle && (fragment || actionFragment || noFiniteVerb || relativeBeforeVerb) {
                atoms.append(make(subject: packet.title, relation: "explains", object: sentence, type: .definition,
                                  span: span, titleSpan: packet.titleSpan, original: sentence))
                titleEstablished = true
                continue
            }
            let main = Decomposition(sentence: work).mainClause
            guard let match = firstVerb(main) else { unresolved.append(raw); continue }
            let before = String(main[..<match.1.lowerBound]).trimmingCharacters(in: .whitespaces)
            let after = String(main[match.1.upperBound...]).trimmingCharacters(in: .whitespaces)
            // Do not let a verb inside a relative/subordinate clause steal the
            // main predicate. Quantifiers alone are not a subject noun phrase.
            guard !before.contains(","), !["one", "two", "some", "all", "every"].contains(before.lowercased()),
                  ![" to ", " but ", " that ", " where ", " when "].contains(where: before.lowercased().contains),
                  !["to", "use", "check", "read", "before"].contains(leading),
                  !["when", "if", "unless"].contains(leading) || !Decomposition(sentence: work).conditions.isEmpty else { unresolved.append(raw); continue }
            let modifiers = Cleaner.modalityQualifiers(in: before)
            var subjectWords = before.split(separator: " ").map(String.init)
            while let last = subjectWords.last, modifiers.contains(where: { $0.text == last.lowercased() }) || ["not", "does", "do", "both", "also"].contains(last.lowercased()) { subjectWords.removeLast() }
            let subject = subjectWords.joined(separator: " ")
            guard !subject.isEmpty, !after.isEmpty else { unresolved.append(raw); continue }
            var pieces: [(Verb, String)] = []
            var currentVerb = match.0, remaining = after
            for _ in 0..<8 {
                let split = [" and ", ", but "].compactMap { connector -> (Range<String.Index>, Verb, String)? in
                    guard let range = remaining.range(of: connector) else { return nil }
                    let tail = String(remaining[range.upperBound...])
                    let probe = "subject " + tail
                    guard let next = firstVerb(probe), String(probe[..<next.1.lowerBound]) == "subject" else { return nil }
                    return (range, next.0, String(probe[next.1.upperBound...]))
                }.min { $0.0.lowerBound < $1.0.lowerBound }
                guard let split else { pieces.append((currentVerb, remaining)); break }
                pieces.append((currentVerb, String(remaining[..<split.0.lowerBound])))
                currentVerb = split.1; remaining = split.2
            }
            for (verb, object) in pieces where !object.isEmpty {
                atoms.append(make(subject: subject, relation: verb.relation, object: object, type: verb.type,
                                  span: span, titleSpan: inherited ? packet.titleSpan : nil, original: sentence))
            }
            if index == 0 { titleEstablished = SemanticIdentity.phrase(subject) == SemanticIdentity.phrase(packet.title) }
        }
        return PacketExtraction(packet: packet, atoms: atoms, unresolved: unresolved)
    }

    private func firstVerb(_ text: String) -> (Verb, Range<String.Index>)? {
        var best: (Verb, Range<String.Index>)?
        // An auxiliary establishes a finite verb phrase. Earlier noun/verb
        // homographs belong to the subject ("requests can both make ...").
        // Do not cross a clause boundary to borrow an embedded auxiliary.
        let auxiliary = text.range(of: #"\s(?:can|could|may|might|must|should|will|does|do)\s+(?:(?:both|also|not|always)\s+)*"#, options: [.regularExpression, .caseInsensitive])
        for verb in Self.verbs {
            for form in [verb.word, verb.word.hasSuffix("s") && !["is"].contains(verb.word) ? String(verb.word.dropLast()) : verb.word] {
                guard let range = text.range(of: " " + form + " ", options: .caseInsensitive) else { continue }
                if let auxiliary, range.lowerBound < auxiliary.lowerBound {
                    let prefix = String(text[..<auxiliary.lowerBound]).lowercased()
                    if ![",", " that ", " which ", " and ", " to "].contains(where: prefix.contains) { continue }
                }
                if let auxiliary, range.lowerBound >= auxiliary.lowerBound {
                    let prefix = String(text[..<auxiliary.lowerBound]).lowercased()
                    if ![",", " that ", " which ", " and ", " to "].contains(where: prefix.contains) {
                        let gap = String(text[auxiliary.lowerBound..<range.lowerBound])
                        guard gap.range(of: #"^\s(?:can|could|may|might|must|should|will|does|do)(?:\s+(?:both|also|not|always))*$"#, options: [.regularExpression, .caseInsensitive]) != nil else { continue }
                    }
                }
                let tail = text[range.upperBound...].lowercased()
                if ["from ", "of ", "with "].contains(where: tail.hasPrefix) { continue }
                // A finite verb cannot take another finite verb as its bare
                // object. Prefer the latter predicate or remain unresolved.
                if Self.verbs.contains(where: { tail.hasPrefix($0.word + " ") || ($0.word.hasSuffix("s") && tail.hasPrefix(String($0.word.dropLast()) + " ")) }) { continue }
                if best == nil || range.lowerBound < best!.1.lowerBound { best = (verb, range) }
            }
        }
        return best
    }

    private func make(subject: String, relation: String, object: String, type: ClaimType, span: SourceSpan, titleSpan: SourceSpan?, original: String) -> KnowledgeAtom {
        let prepared = Decomposition(sentence: original)
        var provenance = Provenance.stated(span)
        if let titleSpan { provenance.spans.append(titleSpan) }
        var identifiers = TextScanning.identifiers(in: original)
        for id in TextScanning.identifiers(in: subject) where !identifiers.contains(id) { identifiers.append(id) }
        return KnowledgeAtom(claimType: type, subject: subject, relation: relation, object: object,
                             concepts: [TextScanning.conceptSlug(subject)], qualifiers: prepared.qualifiers + Cleaner.modalityQualifiers(in: original) + (original.range(of: #"\bboth\b"#, options: [.regularExpression, .caseInsensitive]) == nil ? [] : [.init(kind: .scope, text: "both")]),
                             isNegated: titleSpan != nil && type == .definition ? false : Cleaner.isNegated(Decomposition(sentence: original).mainClause), numbers: TextScanning.numbers(in: original),
                             identifiers: identifiers, conditions: prepared.conditions,
                             sourceIntegrity: titleSpan == nil ? .normalized : .reconstructed, provenance: provenance)
    }
}

/// Order-preserving identity. No stop-word bag, stemming, similarity threshold,
/// or deletion of negation/conditions is allowed to establish equivalence.
public enum SemanticIdentity {
    public static func phrase(_ text: String) -> String {
        var normalized = CanonicalSource.normalized(text).lowercased()
        // Bounded participial alternation: "previously fetched data" and
        // "data fetched earlier" preserve the same argument and time relation.
        if let regex = try? NSRegularExpression(pattern: "previously ([a-z]+ed) ([a-z]+)$") {
            normalized = regex.stringByReplacingMatches(in: normalized, range: NSRange(normalized.startIndex..., in: normalized), withTemplate: "$2 $1 earlier")
        }
        var words = TextScanning.normalizedTokens(normalized)
        if let first = words.first, ["a", "an", "the"].contains(first) { words.removeFirst() }
        return words.joined(separator: " ")
    }
}
