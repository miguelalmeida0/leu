import Foundation
import ShelfCore

extension ReaderModel {
    func quickStudyMark(_ kind: AnnotationKind) async {
        guard kind.isStudyMarker else { return }
        let fragments = displayMode == .original ? controller.captureSelection() : []
        if fragments.isEmpty {
            let sourceQuote = displayMode == .read
                ? String(readablePage.blocks.map(\.text).joined(separator: " ").prefix(360))
                : ""
            let mark = StudyAnnotation(bookID: book.id, pageIndex: pageIndex, kind: kind, color: color(for: kind), rects: [], quote: sourceQuote, note: "")
            do {
                try await repository.addAnnotations([mark])
                try await refreshMarks()
                remember(.added([mark]))
                savedMessage = kind.title + " page saved"
                playHaptic(.mark)
            } catch { errorMessage = error.localizedDescription }
            return
        }
        var draft = NoteDraft(kind: kind, fragments: fragments)
        draft.color = color(for: kind)
        _ = await saveNote(draft)
    }
    private func color(for kind: AnnotationKind) -> MarkColor {
        switch kind {
        case .important: return .amber
        case .review: return .sage
        case .confusing: return .blue
        default: return .amber
        }
    }

    func prepareNote(kind: AnnotationKind = .note) {
        var fragments = displayMode == .original ? controller.captureSelection() : []
        if fragments.isEmpty {
            let sourceQuote = displayMode == .read
                ? String(readablePage.blocks.map(\.text).joined(separator: " ").prefix(360))
                : ""
            fragments = [SelectionFragment(pageIndex: pageIndex, rects: [], quote: sourceQuote)]
        }
        noteDraft = NoteDraft(kind: kind, fragments: fragments)
    }
    func highlight(kind: AnnotationKind) async {
        guard displayMode == .original else {
            errorMessage = "Passage highlighting uses the selectable Original PDF. In Read mode, use Important, Review, Confusing, or Add note to save the current page."
            return
        }
        let fragments = controller.captureSelection()
        guard !fragments.isEmpty else {
            errorMessage = "Select some text in the PDF first. Scanned pages without selectable text can still have page notes and bookmarks."
            return
        }
        _ = await saveNote(NoteDraft(kind: kind, fragments: fragments))
    }
    @discardableResult
    func saveNote(_ draft: NoteDraft) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true; defer { isSaving = false }
        let marks = draft.fragments.map { fragment in
            StudyAnnotation(bookID: book.id, pageIndex: fragment.pageIndex,
                kind: draft.kind, color: draft.color, rects: fragment.rects,
                quote: String(fragment.quote.prefix(100_000)), note: String(draft.text.prefix(100_000)))
        }
        do {
            try await repository.addAnnotations(marks)
            try await refreshMarks()
            controller.clearSelection()
            remember(.added(marks))
            savedMessage = draft.kind.title + " saved"
            playHaptic(.mark)
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func deleteAnnotation(_ mark: StudyAnnotation) async {
        guard !isSaving else { return }
        isSaving = true; defer { isSaving = false }
        do {
            try await repository.removeAnnotation(id: mark.id)
            try await refreshMarks()
            remember(.removed([mark]))
            savedMessage = "Note removed · Undo is available"
        } catch { errorMessage = error.localizedDescription }
    }
    func undo() async {
        guard let change = undoStack.last, !isSaving else { return }
        isSaving = true; defer { isSaving = false }
        do {
            try await apply(change, reversing: true)
            undoStack.removeLast(); redoStack.append(change)
            savedMessage = "Undone"
        } catch { errorMessage = error.localizedDescription }
    }
    func redo() async {
        guard let change = redoStack.last, !isSaving else { return }
        isSaving = true; defer { isSaving = false }
        do {
            try await apply(change, reversing: false)
            redoStack.removeLast(); undoStack.append(change)
            savedMessage = "Redone"
        } catch { errorMessage = error.localizedDescription }
    }
    private func remember(_ change: AnnotationChange) {
        undoStack.append(change)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
    }
    private func apply(_ change: AnnotationChange, reversing: Bool) async throws {
        switch (change, reversing) {
        case (.added(let marks), true), (.removed(let marks), false):
            try await repository.removeAnnotations(ids: Set(marks.map(\.id)))
        case (.added(let marks), false), (.removed(let marks), true):
            try await repository.addAnnotations(marks)
        }
        try await refreshMarks()
    }


    func openStudyMark(_ mark: StudyAnnotation) {
        go(to: mark.pageIndex)
        if displayMode == .original { controller.reveal(mark) }
        savedMessage = mark.quote.isEmpty ? "Saved page opened" : "Saved passage opened"
    }
}
