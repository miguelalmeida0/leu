import Foundation

struct PDFTextReconstructor {
    func reconstruct(_ lines: [PDFClassifiedLine], pageIndex: Int, pageHeight: CGFloat? = nil) -> ReadablePage {
        var blocks: [ReadableBlock] = []
        var accumulated = ""
        var previous: PDFClassifiedLine?
        var kind: ReadableBlock.Kind = .paragraph
        var codeOrigin: CGFloat = 0
        let attestedWords = Set(lines.flatMap { $0.line.text.split(whereSeparator: { !$0.isLetter }).map { $0.lowercased() } })
        func flush() {
            if !accumulated.isEmpty { blocks.append(ReadableBlock(kind: kind, text: accumulated)) }
            accumulated = ""
        }
        for item in lines {
            if let height = pageHeight, item.line.text.range(of: #"^\d+(?:[.\-/]\d+)*$"#, options: .regularExpression) != nil,
               item.line.bounds.minY < height * 0.07 || item.line.bounds.maxY > height * 0.93 { continue }
            let gap = previous.map { $0.line.bounds.minY - item.line.bounds.maxY } ?? 0
            let columnChange = previous.map { abs($0.line.bounds.minX - item.line.bounds.minX) > max(item.kind == .code ? 120 : 40, item.line.bounds.width * 0.5) } ?? false
            let headingLevelChange = previous.map { item.kind == .heading &&
                max($0.line.fontSize, item.line.fontSize) > min($0.line.fontSize, item.line.fontSize) * 1.18 } ?? false
            if item.kind != kind || gap > item.line.fontSize * 0.8 || columnChange || headingLevelChange || item.kind == .bullet { flush() }
            kind = item.kind
            if accumulated.isEmpty { accumulated = item.line.text; codeOrigin = item.line.bounds.minX }
            else if kind == .code {
                let indent = max(0, Int(((item.line.bounds.minX - codeOrigin) / max(1, item.line.fontSize * 0.6)).rounded()))
                accumulated += "\n" + String(repeating: " ", count: min(80, indent)) + item.line.text
            }
            else {
                // Soft hyphens explicitly mark discretionary breaks. Ordinary '-'
                // remains: geometry cannot prove whether a compound is genuine.
                if accumulated.hasSuffix("\u{00AD}") { accumulated.removeLast(); accumulated += item.line.text }
                else if accumulated.hasSuffix("-"), item.line.text.first?.isLowercase == true {
                    let prefix = accumulated.dropLast().split(whereSeparator: { !$0.isLetter }).last.map(String.init) ?? ""
                    let suffix = String(item.line.text.prefix(while: \.isLetter))
                    // Remove a printed break only when the complete word is also
                    // attested on this page. Otherwise preserve the compound's '-'.
                    if attestedWords.contains((prefix + suffix).lowercased()) { accumulated.removeLast() }
                    accumulated += item.line.text
                }
                else { accumulated += " " + item.line.text }
            }
            previous = item
        }
        flush()
        return ReadablePage(pageIndex: pageIndex, blocks: blocks)
    }
}
