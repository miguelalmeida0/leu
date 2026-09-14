# Shelf Native V9 acceptance

V9 is a compiler-stability patch on top of V8.

## Build blocker fixed
- Decomposed `LibraryScreen` into small `@ViewBuilder` sections so Xcode does not have to infer one enormous SwiftUI expression.
- Removed the optional closure ternary from the empty state.
- Moved `UIDocumentPickerViewController` into `PDFDocumentPickerView.swift`.
- Both import entry points still call the exact same `presentPDFPicker()` method.
- Picker remains PDF-only, allows multiple selection, and uses `asCopy: true`.
- Reader mode Binding now uses an explicit closure rather than a method reference.

## Physical-device acceptance
1. Build must complete with no red LibraryScreen compiler diagnostic.
2. Tap + -> iOS Files picker appears.
3. Cancel -> returns to Shelf.
4. Tap Import PDFs in empty state -> the same picker appears.
5. Select one or more PDFs -> visible import status -> files appear in library.
6. Relaunch -> imported PDFs remain.
