# Shelf Native V6 acceptance

Release blockers addressed in this patch:

1. Library + button presents the iOS PDF document picker from the visible Library screen.
2. Selected files are copied under security-scoped access into Shelf-owned storage.
3. Normal builds do not seed bundled demonstration PDFs; existing `isSample` items are purged without touching user imports.
4. Reader defaults to horizontal single-page mode on new installs.
5. Left swipe advances one page; right swipe moves back one page through explicit recognizers layered with PDFKit.
6. Existing arrow buttons remain a deterministic fallback.
7. Vertical continuous scroll remains available in Reader Settings.

Physical-device checks:
- Import one PDF from iCloud Drive and one from On My iPhone.
- Force quit and reopen; imported PDFs remain.
- Open a 50+ page PDF, swipe left ten times, right five times, verify page number and restored position.
- Select vertical mode and confirm continuous scrolling still works.
