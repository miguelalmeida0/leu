import Foundation

struct PDFClassifiedLine {
    let line: PDFSpatialLine
    let kind: ReadableBlock.Kind
}

struct PDFBlockClassifier {
    func classify(_ lines: [PDFSpatialLine]) -> [PDFClassifiedLine] {
        let sizes = lines.flatMap(\.glyphs).filter { !$0.monospaced }.map(\.fontSize).sorted()
        let body = sizes.isEmpty ? 12 : sizes[sizes.count / 2]
        return lines.map { line in
            let text = line.text
            let kind: ReadableBlock.Kind
            if line.monospaced || text.range(of: #"^(?:const |let |func |function |class |import |SELECT |\{|\})"#, options: .regularExpression) != nil { kind = .code }
            else if text.range(of: #"^(?:[•●▪◦*–-]\s+|\d+[.)]\s+)"#, options: .regularExpression) != nil { kind = .bullet }
            else if line.fontSize >= body * 1.18 || (text.count < 90 && text.filter(\.isLetter).count > 2 && text.filter(\.isLetter).allSatisfy(\.isUppercase)) { kind = .heading }
            else { kind = .paragraph }
            return PDFClassifiedLine(line: line, kind: kind)
        }
    }
}
