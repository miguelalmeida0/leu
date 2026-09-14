import PDFKit
import ShelfCore

/// Maps durable, source-coordinate sidecars to portable PDFKit annotations.
enum PDFAnnotationRenderer {
    static let ownerKey = PDFAnnotationKey(rawValue: "ShelfAnnotationID")
    static func apply(_ marks: [StudyAnnotation], to document: PDFDocument) {
        for mark in marks {
            guard let page = document.page(at: mark.pageIndex) else { continue }
            let rects = mark.rects.isEmpty ? [defaultNoteRect(page)] : mark.rects
            for rect in rects {
                let type: PDFAnnotationSubtype = mark.kind == .underline ? .underline
                    : (mark.rects.isEmpty ? .text : .highlight)
                let annotation = PDFAnnotation(bounds: CGRect(x: rect.x, y: rect.y,
                    width: rect.width, height: rect.height), forType: type, withProperties: nil)
                annotation.color = color(mark.color)
                annotation.contents = ([mark.kind.isStudyMarker ? mark.kind.title : "", mark.note]
                    .filter { !$0.isEmpty }).joined(separator: " — ")
                annotation.userName = "Shelf"
                annotation.modificationDate = mark.createdAt
                annotation.setValue(mark.id.uuidString, forAnnotationKey: ownerKey)
                page.addAnnotation(annotation)
            }
        }
    }
    static func remove(_ id: UUID, from document: PDFDocument) {
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            for annotation in page.annotations where annotation.value(forAnnotationKey: ownerKey) as? String == id.uuidString {
                page.removeAnnotation(annotation)
            }
        }
    }
    private static func defaultNoteRect(_ page: PDFPage) -> PDFRect {
        let box = page.bounds(for: .cropBox)
        return PDFRect(x: Double(box.minX + 14), y: Double(box.maxY - 42), width: 24, height: 24)
    }
    private static func color(_ color: MarkColor) -> UIColor {
        switch color {
        case .amber: return UIColor(red: 0.98, green: 0.79, blue: 0.28, alpha: 0.65)
        case .sage: return UIColor(red: 0.50, green: 0.75, blue: 0.49, alpha: 0.6)
        case .blue: return UIColor(red: 0.4, green: 0.67, blue: 0.94, alpha: 0.6)
        case .rose: return UIColor(red: 0.96, green: 0.53, blue: 0.52, alpha: 0.6)
        }
    }
}
