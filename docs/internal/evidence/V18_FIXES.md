# Shelf V18 — Reader stability and UX convergence

This release incorporates the full screen-by-screen audit changes and removes the V4 audit blocker.

## Reader stability
- Original mode is a true single-page PDFKit viewport in horizontal flow; it no longer uses continuous horizontal content offsets as page identity.
- Horizontal page turns in Original mode commit only at fit scale; zoomed pages pan instead. Arrow navigation remains available while zoomed.
- Read and Original scaling are separate preferences (`readTextScale`, `pdfZoomScale`).
- Original offers Fit page, Fit width, zoom in/out. Read offers text sizing only.
- Full-document pull-down dismissal is absent; explicit Back to library owns close.
- Read mode uses prepared adjacent pages with distance/velocity commit thresholds and edge rubber-banding.

## Navigation and retrieval
- Contents distinguishes embedded contents, detected headings, and non-structural page landmarks.
- Outline detection runs after first usable reader load and reconstructs likely wrapped headings.
- Page grid opens around the current page and shows current/bookmark/study state.
- Bookmark icon semantics use the standard bookmark glyph; Favorites remain hearts.
- Search highlights the query, shows section context, uses interactive keyboard dismissal, and navigates through ReaderModel.

## Study and accessibility
- Study cards show section context, excerpts/whole-page state, notes, page number, and a 44pt actions menu.
- Study filters use 44pt minimum controls.
- Reader tool captions increased to 11pt.
- Page indicator now has a dynamic accessibility label: `Page N of M` plus a jump hint.
- UI tests no longer assume the page indicator is exposed as a Button; they query any accessibility descendant and assert the dynamic page label.
- Added Original zoom acceptance coverage: zoomed swipe must not page; arrow must still navigate.

## Validation performed here
- Swift syntax parse: PASS for app, UI tests and integration tests.
- Structural validator: PASS (275 project objects, 125 source/script files, largest file 294 lines).
- ShelfCore: 101/101 tests PASS.
- Apple SDK UI/PDF integration runtime and physical iPhone behavior require execution on the user's Mac/device.
