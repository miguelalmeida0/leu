import Foundation

public struct PDFTextCleaner: Sendable {
    public init() {}

    public func clean(_ raw: String, repeatedHeaders: Set<String> = [], repeatedFooters: Set<String> = []) -> String {
        var text = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        text = repairPaginationHyphens(text)
        var lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        lines = lines.filter { line in
            guard !line.isEmpty else { return true }
            let canonical = line.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
            if repeatedHeaders.contains(canonical) || repeatedFooters.contains(canonical) { return false }
            if line.range(of: #"^\s*\d{1,4}\s*$"#, options: .regularExpression) != nil { return false }
            if line.range(of: #"^(page|chapter)\s+\d{1,4}$"#, options: [.regularExpression, .caseInsensitive]) != nil { return false }
            return true
        }
        return mergeArtificialWraps(lines).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func repairPaginationHyphens(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var output: [String] = []; var index = 0
        while index < lines.count {
            var current = lines[index]
            if current.hasSuffix("-"), index + 1 < lines.count {
                let next = lines[index + 1].trimmingCharacters(in: .whitespaces)
                if let first = next.first, first.isLetter, !isLegitimateHyphenPrefix(current),
                   first.isLowercase || knownSplitPrefix(current) {
                    current.removeLast(); current += next; index += 1
                }
            }
            output.append(current); index += 1
        }
        return output.joined(separator: "\n")
    }

    private func knownSplitPrefix(_ line: String) -> Bool {
        let token = line.dropLast().split(whereSeparator: { $0.isWhitespace }).last.map(String.init)?.lowercased() ?? ""
        return ["java", "type", "ecma"].contains(token)
    }

    private func isLegitimateHyphenPrefix(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.hasSuffix("css-") || lower.hasSuffix("z-") || lower.hasSuffix("client-") || lower.hasSuffix("server-")
    }

    private func mergeArtificialWraps(_ lines: [String]) -> String {
        var output = ""
        for line in lines {
            if line.isEmpty { output += output.hasSuffix("\n\n") ? "" : "\n\n"; continue }
            if output.isEmpty || output.hasSuffix("\n\n") { output += line; continue }
            let previous = output.last
            let startsStructural = line.hasPrefix("•") || line.hasPrefix("- ") || line.hasPrefix("* ")
            if startsStructural || previous == "." || previous == "?" || previous == "!" || previous == ":" { output += "\n" + line }
            else { output += " " + line }
        }
        return output.replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }
}
