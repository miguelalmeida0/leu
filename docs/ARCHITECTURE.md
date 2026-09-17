# Architecture decisions

## Scope and dependencies

Shelf is a native iOS 17+ app composed from SwiftUI, UIKit/PDFKit adapters, and a dependency-free Swift package. It is a personal library, not a distributed document platform. `AppContainer` is the composition root; it constructs services and injects them into presentation models.

```text
SwiftUI screen → feature model → use-case service → repository / adapter contract
                                         ↓
                                   validated domain

PDFReaderSurface → PDFSessionController → PDFView
                         ↑
                   ReaderModel → annotations repository
```

Domain code imports Foundation only. It never depends on PDFKit, Observation, SwiftUI, UIKit, or a global singleton. Storage contracts make malformed files and failed disk writes testable without a UI.

## Responsibilities

| Owner | Responsibility | Must not own |
|---|---|---|
| AppContainer | Construct and connect services | User interaction or document validation |
| RootView | Tabs, routing, presentation | File IO, parsing, business rules |
| Feature views | Layout, labels, accessible actions | Persistence or PDF mutation |
| Observable models | Screen state and use-case orchestration | Drawing, binary PDF processing |
| LibraryRepository actor | Serialized domain transactions | UI state or PDF rendering |
| DocumentImportService actor | Stage, inspect, hash, index, commit import | Picker presentation |
| SnapshotPersistence | Read/write validated metadata checkpoints | Deciding whether a book is a duplicate |
| DocumentVault | UUID-addressed original files | Titles, collections, interface state |
| PDFInspector | Validate/extract one independent PDF | Owning the visible PDFView |
| PDFSessionController | Live rendering, selection and navigation | Saving business data or exporting originals |
| BackupReader/Writer/Merger | Streaming archive, verification, merge semantics | UI decisions or signing |

## Import transaction

1. The incoming-file adapter obtains a security-scoped/coordinated source and stages a stable copy.
2. The import service copies that file into its app-owned vault, then checks the copied byte count.
3. A dedicated PDFKit adapter validates the document and extracts bounded embedded text.
4. A streaming SHA-256 digest establishes identity.
5. Existing hashes resolve to the existing book; a trashed duplicate can be restored without losing notes.
6. The index is disposable. Index failure cannot make a valid saved PDF disappear.
7. A validated metadata snapshot commits atomically. Failed imports discard staged originals.
8. Only after commit does the UI announce success.

Source paths and user-visible titles are never reused as vault paths. Password-locked, empty, invalid, oversized, and interrupted imports fail explicitly. Opening the repository happens before staging originals, so a new library cannot mistake its own first import for a damaged old library.

## Metadata persistence

`JSONSnapshotStore` writes `library.json` atomically and keeps one last valid checkpoint. If the current JSON is corrupt, a valid previous checkpoint can be restored with an explicit recovery flag; the corrupted file is preserved for investigation. Future schema versions are rejected, not silently downgraded.

A missing metadata file alongside existing originals is a recovery condition, not an empty library. This prevents accidental reseeding or overwriting. Snapshot validity includes unique identities, valid references, supported versions, valid page indices, and finite annotation geometry.

The actor commits disk state before replacing its in-memory snapshot. Failed writes preserve the last valid in-memory state. The metadata cap is 32 MiB. This is a deliberate personal-library implementation; a heavier SQLite adapter can replace it behind `SnapshotPersistence` after evidence justifies the migration. Do not claim unmeasured scale.

## Reading and annotations

An immutable `Book` stores a `ReadingPosition` containing page, relative zoom and optional PDF destination. The recorder debounces routine changes and flushes on explicit close/background. Timestamps reject delayed stale position writes.

Original PDF bytes never receive Shelf's edits. `StudyAnnotation` sidecars contain source page, page-coordinate rectangles, quote, note, kind, and color. A renderer applies only Shelf-owned annotations to the visible document. Changes persist before the reader reports success. Multi-page undo is one repository transaction.

Undo/redo is a bounded reader-session history; it is not a durable cross-launch command log. The saved annotations themselves are durable. Export builds a separate document, applies portable annotations, and leaves the original untouched. Existing digital signatures are not claimed to remain valid in edited derivatives.

## Concurrency and resource ownership

Each background service is an actor or an immutable value. PDF inspection, page search, thumbnails and export open independent PDFDocument instances. Only `PDFSessionController` owns the visible `PDFView` on the main actor. The loader's one-shot unchecked-Sendable wrapper transfers a newly created document once to that owner; it must never be cached or concurrently reused.

Search tasks debounce and cancel obsolete work. Search result count, extracted text, thumbnail memory, outline depth, and undo history are bounded. Thumbnails are lazy and disposable. No page loop runs in a SwiftUI body. A device benchmark is still required; architecture is not a measured performance guarantee.

## Backup and deletion

Backups contain originals and full metadata, including Trash. They exclude indexes and interface preferences. A restore is staged, checksummed, validated, and merged before one committed snapshot. Existing local edits are preserved; matching hashes reuse document identities. Backup-contained paths are never accepted.

Trash is reversible. Permanent deletion requires a trashed record and removes metadata first. The previous checkpoint is advanced before the bytes are removed, preventing checkpoint recovery from referencing a newly deleted original. File-cleanup failure can leave an unreferenced file, not a record that silently points at deleted bytes. That tradeoff favors recoverability over aggressive space reclamation.

## Extending the project

A new feature should add domain types/contracts only when needed, then a focused service, tests, and a thin presentation model/view. Keep Swift source below 300 lines. Split by ownership, not arbitrary `Helpers1`/`Helpers2` files.

When adding native source files in Xcode, enable the relevant target membership. The checked-in project uses explicit file references; merely copying a new file into Finder does not add it to the target. Update `docs/internal/evidence/project-manifest.json` or regenerate that inventory when changing membership. The local Swift package discovers its own source files automatically.

Avoid replacing explicit injected services with `static shared` dependencies. Avoid allowing feature screens to obtain URLs and edit originals directly. A future OCR, sync, database, or cloud feature must implement a new boundary without weakening the local reader's guarantees.
