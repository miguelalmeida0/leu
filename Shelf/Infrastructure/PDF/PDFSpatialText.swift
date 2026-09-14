import Foundation
import PDFKit
#if canImport(UIKit)
import UIKit
private typealias PDFTextFont = UIFont
#else
import AppKit
private typealias PDFTextFont = NSFont
#endif

struct PDFGlyph {
    let text: String
    let bounds: CGRect
    let sourceIndex: Int
    let fontSize: CGFloat
    let monospaced: Bool
}

struct PDFSpatialLine {
    let glyphs: [PDFGlyph]
    let bounds: CGRect
    let text: String
    let fontSize: CGFloat
    let monospaced: Bool
}

struct PDFSpatialTextExtractor {
    func glyphs(from page: PDFPage) -> [PDFGlyph] {
        guard let source = page.string else { return [] }
        let attributed = page.attributedString
        // Character geometry is indexed by PDFPage's text, not by a separately
        // reconstructed attributed string (which can have different whitespace).
        let ns = source as NSString
        let alignedAttributes = attributed?.string == source
        let count = min(page.numberOfCharacters, ns.length)
        return (0..<count).compactMap { index in
            let range = ns.rangeOfComposedCharacterSequence(at: index)
            guard range.location == index else { return nil }
            let text = ns.substring(with: range)
            guard text.rangeOfCharacter(from: .newlines) == nil else { return nil }
            // PDFKit 26.5 characterBounds skips inserted linefeeds, although
            // string/selection ranges include them. Pair text and geometry from
            // the SAME selection range; never drop a letter using shifted ink.
            guard let selection = page.selection(for: range), selection.string == text else { return nil }
            let bounds = selection.bounds(for: page)
            guard !bounds.isNull, !bounds.isInfinite, bounds.width > 0, bounds.height > 0 else { return nil }
            let attributes = alignedAttributes ? attributed : page.selection(for: range)?.attributedString
            let attributeIndex = alignedAttributes ? index : 0
            let font = attributes.flatMap { value -> PDFTextFont? in
                guard attributeIndex < value.length else { return nil }
                return value.attribute(.font, at: attributeIndex, effectiveRange: nil) as? PDFTextFont
            }
            #if canImport(UIKit)
            let mono = font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true
            #else
            let mono = font?.fontDescriptor.symbolicTraits.contains(.monoSpace) == true
            #endif
            return PDFGlyph(text: text, bounds: bounds, sourceIndex: index,
                            fontSize: font?.pointSize ?? bounds.height, monospaced: mono)
        }
    }
}
