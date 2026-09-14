import SwiftUI
import UniformTypeIdentifiers
import UIKit

@MainActor
struct PDFDocumentPickerView: UIViewControllerRepresentable {
    let didPick: ([URL]) -> Void
    let didCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(didPick: didPick, didCancel: didCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf],
            asCopy: true
        )
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = true
        controller.shouldShowFileExtensions = true
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let didPick: ([URL]) -> Void
        private let didCancel: () -> Void

        init(
            didPick: @escaping ([URL]) -> Void,
            didCancel: @escaping () -> Void
        ) {
            self.didPick = didPick
            self.didCancel = didCancel
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            didPick(urls)
        }

        func documentPickerWasCancelled(
            _ controller: UIDocumentPickerViewController
        ) {
            didCancel()
        }
    }
}
