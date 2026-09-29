import XCTest
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `claude/v37-capability-spike`, never merged).

/// Deterministic answer segmentation for the spike: V35's own clause splitter, then a split at a
/// reason marker so the model (and V35's own reason rule) see the reason as its own segment. The
/// marker stays with the part it introduces. At most 16 segments.
enum SpikeSegmenter {
    static let maximum = 16
    static let reasonMarker = try! NSRegularExpression(
        pattern: #"(?i)\b(because|since|therefore|thus|hence|that's why|that is why|which means|due to|as a result)\b"#)
    /// Markers that introduce a reason, as opposed to a conclusion ("therefore", "thus"...).
    static let introducesReason: Set<String> = ["because", "since", "due to", "as a result"]

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
        XCTAssertEqual(SpikeSegmenter.segments("JWTs are signed so nobody can read them."), ["JWTs are signed so nobody can read them."])
        XCTAssertEqual(SpikeSegmenter.segments("It's fast."), ["It's fast."])
        XCTAssertEqual(SpikeSegmenter.segments("Fast."), [], "a one-word answer has no segment: recorded as empty, no model call")
        XCTAssertEqual(SpikeSegmenter.leadingMarker("because JavaScript copies it"), "because")
        XCTAssertNil(SpikeSegmenter.leadingMarker("JavaScript copies it because"))
    }
}
