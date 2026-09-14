import Foundation

struct PDFLineGrouper {
    func lines(from glyphs: [PDFGlyph], pageWidth: CGFloat, diagnostics: Bool = false) -> [PDFSpatialLine] {
        var bands: [[PDFGlyph]] = []
        for glyph in glyphs.sorted(by: { $0.bounds.midY == $1.bounds.midY ? $0.bounds.minX < $1.bounds.minX : $0.bounds.midY > $1.bounds.midY }) {
            if let i = bands.lastIndex(where: { band in
                guard let anchor = band.max(by: { $0.bounds.height < $1.bounds.height }) else { return false }
                // Ink height is not line height: a period must share the band's
                // baseline with letters, rather than getting a sub-pixel tolerance.
                let em = max(anchor.fontSize, glyph.fontSize)
                return abs(anchor.bounds.midY - glyph.bounds.midY) <= em * 0.5
            }) { bands[i].append(glyph) } else { bands.append([glyph]) }
        }
        if diagnostics {
            for (index, band) in bands.enumerated() {
                print("[leu-pdf] y-band=\(index) glyphs=\(band.map { "\($0.sourceIndex):\($0.text):\($0.bounds)" })")
            }
        }
        var lines: [PDFSpatialLine] = []
        for band in bands {
            var run: [PDFGlyph] = []
            for glyph in band.sorted(by: { $0.bounds.minX == $1.bounds.minX ? $0.sourceIndex < $1.sourceIndex : $0.bounds.minX < $1.bounds.minX }) {
                if let previous = run.last,
                   glyph.bounds.minX - previous.bounds.maxX > max(24, previous.fontSize * 2.5) {
                    if let line = makeLine(run) { lines.append(line) }; run = []
                }
                run.append(glyph)
            }
            if let line = makeLine(run) { lines.append(line) }
        }
        return columnOrder(lines, pageWidth: pageWidth)
    }

    private func makeLine(_ glyphs: [PDFGlyph]) -> PDFSpatialLine? {
        let ink = glyphs.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let first = ink.first else { return nil }
        let gaps = zip(ink, ink.dropFirst()).map { max(0, $1.bounds.minX - $0.bounds.maxX) }.sorted()
        let tracking = gaps.isEmpty ? 0 : gaps[gaps.count / 2]
        // A tracked small-caps label ("IN ONE BREATH") is emitted as separately
        // positioned glyphs, and PDFKit's own string puts a space between every
        // one of them. Those spaces are an extraction artifact, not word
        // boundaries, so on such a line geometry decides and the wider word gap
        // is the only thing that becomes a space.
        let singleLetters = ink.filter { $0.text.count == 1 && $0.text.first?.isLetter == true }
        let tracked = ink.count >= 6 && tracking > first.fontSize * 0.18
            && Double(singleLetters.count) / Double(ink.count) > 0.8
        let spaceThreshold = max(first.fontSize * 0.20, tracking * (tracked ? 1.8 : 2.6))
        var text = ""
        var previous: PDFGlyph?
        for glyph in ink {
            if let previous {
                let explicitSpace = glyphs.contains { $0.sourceIndex > previous.sourceIndex && $0.sourceIndex < glyph.sourceIndex && $0.text == " " }
                let gap = glyph.bounds.minX - previous.bounds.maxX
                if (explicitSpace && !tracked) || gap > spaceThreshold { text += " " }
            }
            text += glyph.text; previous = glyph
        }
        let bounds = ink.reduce(CGRect.null) { $0.union($1.bounds) }
        return PDFSpatialLine(glyphs: ink, bounds: bounds, text: text,
                              fontSize: ink.map(\.fontSize).sorted()[ink.count / 2],
                              monospaced: ink.filter(\.monospaced).count * 2 > ink.count)
    }

    private func columnOrder(_ lines: [PDFSpatialLine], pageWidth: CGFloat) -> [PDFSpatialLine] {
        let vertical = lines.sorted { $0.bounds.maxY > $1.bounds.maxY }
        // Spanning headings divide the page into independent reading regions.
        var result: [PDFSpatialLine] = [], region: [PDFSpatialLine] = []
        func flush() {
            let midpoint = pageWidth / 2
            let left = region.filter { $0.bounds.maxX < midpoint + 8 }
            let right = region.filter { $0.bounds.minX > midpoint - 8 }
            if left.count >= 2, right.count >= 2, left.count + right.count == region.count {
                result += left.sorted { $0.bounds.maxY > $1.bounds.maxY }
                result += right.sorted { $0.bounds.maxY > $1.bounds.maxY }
            } else { result += region }
            region = []
        }
        for line in vertical {
            if line.bounds.width > pageWidth * 0.65 { flush(); result.append(line) }
            else { region.append(line) }
        }
        flush()
        return result
    }
}
