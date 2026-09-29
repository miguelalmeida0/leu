import XCTest
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `test`, never merged into dev before a pass).

/// Deterministic answer segmentation for the spike: V35's own clause splitter, then a split at a
/// discourse marker so the model (and V35's own reason rule) see a reason or a conclusion as its own
/// segment. The marker stays with the part it introduces. At most 16 segments.
///
/// V37 composition: the markers also fix which segment is the reason and which the conclusion, in
/// either direction ("X because Y": Y → X; "X, so Y" / "X therefore Y": X → Y; "Because X, Y": X → Y).
/// These links are general discourse structure, not domain rules.
enum SpikeSegmenter {
    static let maximum = 16
    /// "so" only as a connective: not "so that" (purpose) or "so far/much/many/long/well/as" (degree).
    static let reasonMarker = try! NSRegularExpression(
        pattern: #"(?i)\b(because|since|therefore|thus|hence|consequently|that's why|that is why|which means|due to|as a result|so(?!\s+(?:that|as|far|much|many|long|well)\b))\b"#)
    /// Markers that introduce a reason, as opposed to a conclusion ("therefore", "so"...).
    static let introducesReason: Set<String> = ["because", "since", "due to"]
    /// Markers that introduce a conclusion drawn from what came before.
    static let introducesConclusion: Set<String> = ["so", "therefore", "thus", "hence", "consequently", "that's why", "that is why",
                                                    "which means", "as a result"]
    /// What V35's clause splitter consumes between two clauses (", so ", ", which "): read from the gap.
    static let gapConclusion = try! NSRegularExpression(pattern: #"(?i)(?:^|[\s,;])(?:so|therefore|thus|hence)(?:[\s,]|$)"#)
    static let gapWhich = try! NSRegularExpression(pattern: #"(?i)(?:^|[\s,;])which(?:[\s,]|$)"#)

    static func segments(_ text: String) -> [String] {
        var result = DiagnosisText.clauses(String(text.prefix(4000))).flatMap(split)
        if result.count > maximum {
            result = Array(result.prefix(maximum - 1)) + [result.dropFirst(maximum - 1).joined(separator: " ")]
        }
        return result
    }

    private static func words(_ text: String) -> Int { text.split(whereSeparator: \.isWhitespace).count }

    /// "X because Y" → ["X", "because Y"]; "Because X, Y" → ["Because X", "Y"]. Applied again to the rest.
    static func split(_ clause: String) -> [String] {
        let text = clause.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(text.startIndex..., in: text)
        guard let match = reasonMarker.firstMatch(in: text, range: range), let marker = Range(match.range, in: text) else { return [text] }
        if marker.lowerBound == text.startIndex {
            // A leading conclusion marker ("As a result, Y", "So, Y") introduces the whole clause: it stays one
            // segment, linked to the one before it.
            if introducesConclusion.contains(text[marker].lowercased()) { return [text] }
            // Leading reason clause: split at the first comma after the marker.
            guard let comma = text[marker.upperBound...].firstIndex(of: ",") else { return [text] }
            let head = String(text[..<comma]).trimmingCharacters(in: .whitespaces)
            let tail = String(text[text.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
            guard words(head) >= 3, words(tail) >= 2 else { return [text] }
            return [head] + split(tail)
        }
        let head = String(text[..<marker.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:")))
        let tail = String(text[marker.lowerBound...]).trimmingCharacters(in: .whitespaces)
        guard words(head) >= 2, words(tail) >= 3 else { return [text] }
        return [head] + splitRest(tail)
    }

    /// Splits the part that starts with a marker again, at a later marker only.
    private static func splitRest(_ text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        let matches = reasonMarker.matches(in: text, range: range)
        guard matches.count > 1, let second = Range(matches[1].range, in: text) else { return [text] }
        let head = String(text[..<second.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:")))
        let tail = String(text[second.lowerBound...]).trimmingCharacters(in: .whitespaces)
        guard words(head) >= 3, words(tail) >= 3 else { return [text] }
        return [head] + splitRest(tail)
    }

    /// Reason → conclusion links fixed by the answer's own discourse markers, between neighbouring
    /// segments (1-based). The text between two segments carries what V35's splitter consumed.
    static func links(_ segments: [String], text: String) -> [(reason: Int, conclusion: Int)] {
        var ranges: [Range<String.Index>?] = [], cursor = text.startIndex
        for segment in segments {
            let found = text.range(of: segment, range: cursor..<text.endIndex)
            ranges.append(found)
            if let found { cursor = found.upperBound }
        }
        func gap(_ i: Int) -> String {   // the text between segment i-1 and segment i
            guard let a = ranges[i - 1], let b = ranges[i], a.upperBound <= b.lowerBound else { return "" }
            return String(text[a.upperBound..<b.lowerBound])
        }
        func sameSentence(_ i: Int) -> Bool { !gap(i).contains(where: { ".!?".contains($0) }) }
        // "Because X, Y" at the start of a sentence: X explains the clause after it, not the one before.
        func leadingReason(_ i: Int) -> Bool {
            guard let marker = leadingMarker(segments[i]), introducesReason.contains(marker), i + 1 < segments.count, sameSentence(i + 1),
                  let range = ranges[i] else { return false }
            return isSentenceStart(range.lowerBound, in: text)
        }
        var result: [(reason: Int, conclusion: Int)] = []
        for i in segments.indices {
            if leadingReason(i) { result.append((i + 1, i + 2)); continue }
            guard i > 0 else { continue }
            let g = gap(i)
            if let marker = leadingMarker(segments[i]), introducesReason.contains(marker) {
                result.append((i + 1, i))                                    // "X because Y": Y explains X
            } else if let marker = leadingMarker(segments[i]), introducesConclusion.contains(marker) {
                result.append((i, i + 1))                                    // "X so Y": Y follows from X
            } else if gapConclusion.firstMatch(in: g, range: NSRange(g.startIndex..., in: g)) != nil
                        || (gapWhich.firstMatch(in: g, range: NSRange(g.startIndex..., in: g)) != nil
                            && ["means", "is why"].contains(where: segments[i].lowercased().hasPrefix)) {
                result.append((i, i + 1))                                    // "X, so Y" / "X, which means Y" (marker consumed)
            }
        }
        return result
    }

    static func isSentenceStart(_ index: String.Index, in text: String) -> Bool {
        let before = text[..<index].trimmingCharacters(in: .whitespacesAndNewlines)
        return before.isEmpty || [".", "!", "?", ":"].contains(before.last.map(String.init) ?? "")
    }

    /// The marker a segment starts with, lower-cased, if any.
    static func leadingMarker(_ segment: String) -> String? {
        let range = NSRange(segment.startIndex..., in: segment)
        guard let match = reasonMarker.firstMatch(in: segment, range: range), match.range.location == 0,
              let marker = Range(match.range, in: segment) else { return nil }
        return segment[marker].lowercased()
    }
}

/// Exports the runner's input file for a case set. Runs only when `LEU_SPIKE_CASES` (a fixture),
/// `LEU_SPIKE_SET` and `LEU_SPIKE_EXPORT` (the output file) are set. Prints counts only.
final class ZZSpikeExport: XCTestCase {
    func testExportInputs() throws {
        let env = ProcessInfo.processInfo.environment
        guard let casesPath = env["LEU_SPIKE_CASES"], let set = env["LEU_SPIKE_SET"], let output = env["LEU_SPIKE_EXPORT"] else { return }
        let fixture = try JSONDecoder().decode(GeneralizationEvaluation.Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: casesPath)))
        var inputs: [SpikeInput] = []
        for item in fixture.cases {
            let target = try XCTUnwrap(GeneralizationEvaluation.target(for: item), "no target for a case")
            inputs.append(SpikeInput.make(item, set: set, target: target))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(SpikeInputFile(set: set, cases: inputs)).write(to: URL(fileURLWithPath: output))
        let segments = inputs.map(\.segments.count)
        print("SPIKE-EXPORT set=\(set) cases=\(inputs.count) targets=\(Set(inputs.map(\.targetKey)).count) "
              + "segments total=\(segments.reduce(0, +)) max=\(segments.max() ?? 0) le80words=\(inputs.filter { $0.wordCount <= 80 }.count)")
    }

    func testSegmenterSplitsReasonsAndKeepsMarkers() {
        XCTAssertEqual(SpikeSegmenter.segments("The inner function can still access the outer variable because JavaScript copies all outer variables into it."),
                       ["The inner function can still access the outer variable", "because JavaScript copies all outer variables into it."])
        XCTAssertEqual(SpikeSegmenter.segments("Because the server checks it every time, nobody can fake a token."),
                       ["Because the server checks it every time", "nobody can fake a token."])
        XCTAssertEqual(SpikeSegmenter.segments("JWTs are signed so nobody can read them."), ["JWTs are signed", "so nobody can read them."],
                       "V37: a conclusion marker splits too (risk 3)")
        XCTAssertEqual(SpikeSegmenter.segments("It's fast."), ["It's fast."])
        XCTAssertEqual(SpikeSegmenter.segments("Fast."), [], "a one-word answer has no segment: recorded as empty, no model call")
        XCTAssertEqual(SpikeSegmenter.leadingMarker("because JavaScript copies it"), "because")
        XCTAssertNil(SpikeSegmenter.leadingMarker("JavaScript copies it because"))
    }
}
