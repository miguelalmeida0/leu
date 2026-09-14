import Foundation

public struct SourcePageInput: Codable, Equatable, Sendable {
    public var pageIndex: Int
    public var text: String
    public init(pageIndex: Int, text: String) { self.pageIndex = pageIndex; self.text = text }
}

public struct DocumentAnalyzer: Sendable {
    public static let algorithmVersion = 2

    public init() {}

    public func analyze(documentID: UUID, fingerprint: String, pages: [SourcePageInput]) -> DocumentAnalysis {
        let normalized = pages.map { SourcePageInput(pageIndex: $0.pageIndex, text: normalize($0.text)) }
        let headerCandidates = repeatedEdgeLines(in: normalized, fromTop: true)
        let footerCandidates = repeatedEdgeLines(in: normalized, fromTop: false)
        var analyzed: [AnalyzedPage] = []
        var activeSection: String?

        for page in normalized {
            let cleaned = removeEdges(page.text, headers: headerCandidates, footers: footerCandidates)
            let rawBlocks = paragraphBlocks(cleaned)
            var segments: [SourceSegment] = []
            for block in rawBlocks {
                let kind = classify(block)
                if kind == .heading { activeSection = block }
                let segment = SourceSegment(
                    id: StableIdentity.uuid("segment|\(documentID)|\(page.pageIndex)|\(block)"),
                    pageIndex: page.pageIndex,
                    kind: kind,
                    text: block,
                    sectionTitle: kind == .heading ? block : activeSection,
                    importance: importance(of: block, kind: kind)
                )
                segments.append(segment)
            }
            analyzed.append(AnalyzedPage(pageIndex: page.pageIndex, normalizedText: cleaned, segments: segments))
        }
        return DocumentAnalysis(documentID: documentID, fingerprint: fingerprint,
                                algorithmVersion: Self.algorithmVersion, pages: analyzed,
                                repeatedHeaders: headerCandidates.sorted(), repeatedFooters: footerCandidates.sorted())
    }

    public func normalize(_ raw: String) -> String {
        var text = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        text = repairHyphenation(text)
        let lines = text.components(separatedBy: "\n").map { line in
            line.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        }
        return lines.joined(separator: "\n").replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func repairHyphenation(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var index = 0
        while index < lines.count {
            var line = lines[index]
            if line.hasSuffix("-") && index + 1 < lines.count {
                let next = lines[index + 1].trimmingCharacters(in: .whitespaces)
                if let first = next.first, first.isLowercase {
                    line.removeLast()
                    line += next
                    index += 1
                }
            }
            result.append(line)
            index += 1
        }
        return result.joined(separator: "\n")
    }

    private func repeatedEdgeLines(in pages: [SourcePageInput], fromTop: Bool) -> Set<String> {
        guard pages.count >= 3 else { return [] }
        var counts: [String: Int] = [:]
        for page in pages {
            let lines = page.text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let candidates = fromTop ? Array(lines.prefix(2)) : Array(lines.suffix(2))
            for line in Set(candidates.map(canonicalEdge).filter { $0.count >= 3 }) { counts[line, default: 0] += 1 }
        }
        let threshold = max(3, Int(ceil(Double(pages.count) * 0.6)))
        return Set(counts.filter { $0.value >= threshold }.map(\.key))
    }

    private func canonicalEdge(_ line: String) -> String {
        line.lowercased().split { $0.isWhitespace }.joined(separator: " ")
            .replacingOccurrences(of: #"\d+"#, with: "#", options: .regularExpression)
    }

    private func removeEdges(_ text: String, headers: Set<String>, footers: Set<String>) -> String {
        text.components(separatedBy: "\n").filter { line in
            let canonical = canonicalEdge(line)
            return !headers.contains(canonical) && !footers.contains(canonical)
        }.joined(separator: "\n")
    }

    private func paragraphBlocks(_ text: String) -> [String] {
        var blocks: [String] = []
        var current = ""
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                if !current.isEmpty { blocks.append(current); current = "" }
                continue
            }
            if isStandalone(line) {
                if !current.isEmpty { blocks.append(current); current = "" }
                blocks.append(line)
            } else {
                current += (current.isEmpty ? "" : " ") + line
            }
        }
        if !current.isEmpty { blocks.append(current) }
        return blocks.filter { $0.count >= 2 }
    }

    private func isStandalone(_ line: String) -> Bool {
        isList(line) || isHeading(line) || line.hasPrefix("//") || line.hasPrefix("{") || line.hasSuffix(";")
    }

    private func classify(_ text: String) -> SourceSegmentKind {
        if isHeading(text) { return .heading }
        if isList(text) { return .listItem }
        if definitionParts(text) != nil { return .definition }
        if text.hasPrefix("//") || text.contains("=>") || text.contains("const ") || text.contains("func ") { return .code }
        return .paragraph
    }

    private func isList(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("•") || t.hasPrefix("-") || t.hasPrefix("* ") || t.range(of: #"^\d+[.)]\s"#, options: .regularExpression) != nil
    }

    private func isHeading(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3, trimmed.count <= 90, !trimmed.hasSuffix(".") else { return false }
        let letters = trimmed.filter(\.isLetter)
        guard !letters.isEmpty else { return false }
        let upper = letters.filter(\.isUppercase).count
        let words = trimmed.split(separator: " ")
        if Double(upper) / Double(letters.count) > 0.72 && words.count <= 10 { return true }
        if words.count <= 8 && trimmed.last == ":" { return true }
        return false
    }

    private func definitionParts(_ text: String) -> (String, String)? {
        for separator in [" is defined as ", " refers to ", " means ", " describes ", " is "] {
            if let range = text.range(of: separator, options: .caseInsensitive) {
                let lhs = text[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                let rhs = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if lhs.count >= 2, lhs.count <= 80, rhs.count >= 8 { return (lhs, rhs) }
            }
        }
        return nil
    }

    private func importance(of text: String, kind: SourceSegmentKind) -> Double {
        var score = kind == .heading ? 0.9 : (kind == .definition ? 0.82 : 0.48)
        if text.count >= 40 && text.count <= 240 { score += 0.08 }
        if text.contains(":") { score += 0.03 }
        return min(score, 1)
    }
}
