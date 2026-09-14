# Shelf Native V19.2 — physical-device acceptance

V19.2 exists to close the gap between the green V18.2 simulator audit and the interaction defects reproduced on a physical iPhone. Do not qualify the release from test counts alone.

## Required Mac audit

Run:

```bash
./scripts/qa-and-copy.sh
```

The script saves the full log as `qa-v19-1.log`, writes a compact summary, shows that summary, and copies it to the macOS clipboard. It runs structural/import/UI-contract checks, a native simulator compile gate, the 120 portable core tests, all Apple PDF/PDFKit tests, and all XCUITests.

Expected automated scope in this source package:

- 120 portable core tests.
- 12 Apple PDF/PDFKit integration/geometry tests.
- 32 UI/regression journeys.
- Tests 22–31 specifically cover the V19 interaction repairs.

## Physical iPhone gate

Use a real multi-page PDF, including the large interview PDF that exposed the issue.

1. **Original · Fit page · normal reader** — swipe left and right across at least 20 pages. Each settled state shows one page only. Moderate vertical thumb drift during a horizontal swipe must not move the PDF up/down. A vertical drag at fit must not displace the page.
2. **Original · Fit page · focus mode** — repeat page turns. The reserved focus strip remains above the document and never overlaps printed content.
3. **Original · zoomed** — pinch above fit and pan in every direction. One-finger pan must not change page. Previous/next arrows must still change exactly one page. Returning to Fit page restores horizontal page turning.
4. **Original · mixed geometry** — navigate through portrait, landscape, rotated, and differently sized PDF pages if available. No partial neighbor page, blank sliver, stale page number, or off-center settled state.
5. **Read · Horizontal pages** — left/right drag follows the finger, vertical text scrolling still works within a page, reversal cancels correctly, and one gesture commits at most one page.
6. **Read · Vertical scroll** — scroll continuously across at least three source-page boundaries. Bottom arrows must jump to the requested source page and scrolling must continue from there. Switch Vertical → Horizontal → Vertical and verify paging remains active.
7. **Reading appearance controls** — drag Read text size and brightness from several initial touch locations. The first contact must change the control; the thumb must remain opaque/visible. Keep Screen Awake toggles on the first tap.
8. **Bottom reader bar** — Previous, page indicator/jump, Next, Play/Pause/Resume, Bookmark, scrubber, Contents, Search, Mark, Study, and Text/Zoom are individually hittable. Scrubbing must not move the playback row. The Play button has visible breathing room above and below.
9. **Persistence** — move to a distant page, close Shelf, reopen, and verify the same reading page. Repeat after vertical Read scrolling and after Original-mode navigation.
10. **Accessibility/comfort** — repeat critical controls with larger Dynamic Type and Reduce Motion. No control overlaps the document or becomes unreachable.

A failure in any item above is a release blocker for V19.2.
