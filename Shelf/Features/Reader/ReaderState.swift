import Foundation
import ShelfCore

enum ReaderPanel: String, Identifiable { case contents, search, notes, settings, readingState, time; var id: Self { self } }

struct SelectionFragment {
    let pageIndex: Int
    let rects: [PDFRect]
    let quote: String
}

struct NoteDraft: Identifiable {
    let id = UUID()
    var kind: AnnotationKind
    var color: MarkColor = .amber
    var text = ""
    var fragments: [SelectionFragment]
    var quote: String { fragments.map(\.quote).filter { !$0.isEmpty }.joined(separator: "\n") }
}

enum AnnotationChange {
    case added([StudyAnnotation])
    case removed([StudyAnnotation])
}
