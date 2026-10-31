# Reader fit, page turns and Contents

Original opens at **Fit page**: the complete source sheet fits inside the reading viewport at its original aspect ratio. The display width is `min(viewportWidth, viewportHeight * sourceAspect)`. The centered reader surface is white, preserving intrinsic PDF whitespace. This intentionally replaces the former cropped Fill screen default and removes that option.

At normal zoom, a horizontal drag follows the pointer and settles onto one source page. Direction locks after a small movement; distance or velocity commits the turn. First and last source pages resist. A cancelled gesture, a transition to pinch, or a resize cannot commit a stray page. Animation accepts one turn at a time; wheel momentum stays latched for its burst.

Pinch zoom above 105% assigns the gesture to bounded panning. Reaching a pan boundary never becomes a page turn or pull-to-exit. Reset zoom and keyboard `0` restore Fit page and normal paging. Fit width remains an explicit option for tall source sheets, with vertical scrolling and the same horizontal source turns. A normal-zoom pull from the top exits fullscreen. Edge taps, page buttons, arrow/Page keys, rebuilt screen pagination, saved passages and reading controls remain available.

Contents is shared by the book overview, ordinary reader and fullscreen controls. Its disclosure shows the current outline index. The dialog searches titles, indices and page numbers; every imported entry remains available, including nested entries and repeated titles. Long text wraps within the available width and indentation is bounded. A selected entry closes the dialog and restores disclosure focus after page navigation. Escape and outside press close it. Short-height viewports scroll the dialog while retaining a usable result list.

The PDF importer traverses the complete embedded outline in preorder with an explicit stack. It retains the existing outline deadline and skips broken destinations while continuing through valid children.

Regression journeys:

- `node scripts/reader-pagination-journeys.mjs`: actual portrait, landscape and tall PDFs; real pointer/touch input, fit/aspect, pan/reset, boundaries, cancellation/pinch, rotation, momentum and saved-passage reload.
- `node scripts/reader-contents-journeys.mjs`: actual imported twelve-level PDF outline; 500 long/deep/repeated headings; final result selection, source jumps, focus and dismissal, toolbar bounds, responsive widths and short/keyboard-height viewports.

Both scripts run in the required browser CI job. Existing broad browser, reading-room, dismissal, accessibility, unit, motion and stress gates remain required.
