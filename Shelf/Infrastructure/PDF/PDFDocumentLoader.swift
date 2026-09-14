import PDFKit
import ShelfCore

enum OutlineSource: String, Sendable {
    case embedded
    case detected
    case landmark
}

struct OutlineEntry: Identifiable, Sendable {
    let id: String
    let title: String
    let pageIndex: Int
    let depth: Int
    let source: OutlineSource

    var isStructuralBoundary: Bool { source != .landmark && depth <= 1 }
}

/// The PDF is transferred once to the main actor; it is never used by the loading actor afterward.
struct LoadedPDF: @unchecked Sendable {
    let document: PDFDocument
    let outline: [OutlineEntry]
}

actor PDFDocumentLoader {
    func load(url: URL) throws -> LoadedPDF {
        guard let document = PDFDocument(url: url), !document.isLocked else {
            throw ShelfError.invalidPDF("The stored document could not be opened.")
        }

        var entries: [OutlineEntry] = []
        if let root = document.outlineRoot {
            flatten(root, document: document, depth: -1, into: &entries)
        }

        return LoadedPDF(document: document, outline: entries)
    }

    /// Reopens the file on the loader actor so expensive heading inference never blocks the
    /// reader's first usable frame or shares a PDFDocument across actors.
    func detectOutline(url: URL) throws -> [OutlineEntry] {
        guard let document = PDFDocument(url: url), !document.isLocked else { return [] }
        return inferredOutline(from: document)
    }

    private func flatten(_ node: PDFOutline, document: PDFDocument, depth: Int, into entries: inout [OutlineEntry]) {
        guard depth < 12, entries.count < 2_000 else { return }
        if depth >= 0,
           let title = node.label?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty,
           let destination = node.destination ?? (node.action as? PDFActionGoTo)?.destination,
           let page = destination.page {
            let index = document.index(for: page)
            if index != NSNotFound {
                entries.append(OutlineEntry(
                    id: "embedded-\(entries.count)-\(index)",
                    title: title,
                    pageIndex: index,
                    depth: depth,
                    source: .embedded
                ))
            }
        }
        for index in 0..<node.numberOfChildren {
            if let child = node.child(at: index) {
                flatten(child, document: document, depth: depth + 1, into: &entries)
            }
        }
    }

    private func inferredOutline(from document: PDFDocument) -> [OutlineEntry] {
        var result: [OutlineEntry] = []
        var previousTitle: String?

        for pageIndex in 0..<document.pageCount {
            guard let text = document.page(at: pageIndex)?.string,
                  let candidate = inferredTitle(from: text),
                  candidate.title.caseInsensitiveCompare(previousTitle ?? "") != .orderedSame else { continue }

            result.append(OutlineEntry(
                id: "detected-\(pageIndex)",
                title: candidate.title,
                pageIndex: pageIndex,
                depth: candidate.depth,
                source: .detected
            ))
            previousTitle = candidate.title
        }

        // Landmarks are navigation fallbacks, not chapters. Keep them semantically separate so
        // time planning and chapter haptics never treat every sampled page as a section boundary.
        if result.count < 3, document.pageCount > 0 {
            let stride = max(1, document.pageCount / 24)
            return Swift.stride(from: 0, to: document.pageCount, by: stride).map { index in
                let fallback = document.page(at: index)?.string.flatMap(inferredTitle(from:))?.title
                return OutlineEntry(
                    id: "landmark-\(index)",
                    title: fallback ?? "Page \(index + 1)",
                    pageIndex: index,
                    depth: 3,
                    source: .landmark
                )
            }
        }

        return result
    }

    private func inferredTitle(from pageText: String) -> (title: String, depth: Int)? {
        let rawLines = pageText
            .split(whereSeparator: \.isNewline)
            .map { cleanedHeading(String($0)) }
            .filter { !$0.isEmpty }
        let lines = Array(rawLines.prefix(16))
        guard !lines.isEmpty else { return nil }

        var candidates: [(String, Int)] = []
        for (index, line) in lines.enumerated() {
            if let score = headingScore(line) {
                candidates.append((line, score))

                // Reconstruct wrapped headings. This specifically avoids fragment-only contents
                // such as “Train your mouth, not just” when the continuation is on the next line.
                if index + 1 < lines.count {
                    let next = lines[index + 1]
                    let merged = line + " " + next
                    if merged.count <= 118,
                       !line.hasSuffix("."),
                       !line.hasSuffix(":"),
                       next.count <= 72,
                       !looksLikeFooter(next),
                       next.range(of: #"^\d{1,4}$"#, options: .regularExpression) == nil {
                        let continuationBonus = next.first?.isLowercase == true ? 26 : 12
                        candidates.append((merged, score + continuationBonus))
                    }
                }
            }
        }

        guard let best = candidates.max(by: { $0.1 < $1.1 })?.0 else { return nil }
        return (best, headingDepth(best))
    }

    private func headingScore(_ line: String) -> Int? {
        guard line.count >= 4, line.count <= 96 else { return nil }
        guard line.range(of: #"^\d{1,4}$"#, options: .regularExpression) == nil else { return nil }
        guard !looksLikeFooter(line) else { return nil }

        let letters = line.filter(\.isLetter)
        guard !letters.isEmpty else { return nil }

        var score = 0
        if (8...62).contains(line.count) { score += 35 }
        if !line.hasSuffix(".") { score += 15 }
        if line.first?.isUppercase == true { score += 10 }
        if line.contains("•") || line.contains("|") { score -= 12 }
        if line.hasSuffix("?") { score += 12 }

        let lowercaseWords = line.split(separator: " ").filter { $0.first?.isLowercase == true }.count
        if lowercaseWords > 0 { score += 10 }

        let uppercaseLetters = letters.filter(\.isUppercase).count
        let uppercaseRatio = Double(uppercaseLetters) / Double(max(letters.count, 1))
        if uppercaseRatio > 0.82 {
            score += line.count <= 34 ? 8 : -18
        } else {
            score += 18
        }

        return score
    }

    private func headingDepth(_ title: String) -> Int {
        let normalized = title.lowercased()
        if normalized.hasPrefix("section ") || normalized.hasPrefix("chapter ") || normalized.hasPrefix("part ") {
            return 0
        }
        let letters = title.filter(\.isLetter)
        if !letters.isEmpty {
            let uppercaseRatio = Double(letters.filter(\.isUppercase).count) / Double(letters.count)
            if uppercaseRatio > 0.78 && title.count <= 46 { return 0 }
        }
        return 1
    }

    private func cleanedHeading(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: #"^\s*\d{1,4}\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func looksLikeFooter(_ line: String) -> Bool {
        let value = line.lowercased()
        return value.contains("copyright") ||
            value.contains("all rights reserved") ||
            value.hasPrefix("page ") ||
            value.contains("http://") ||
            value.contains("https://")
    }
}
