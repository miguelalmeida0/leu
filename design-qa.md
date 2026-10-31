# Leu reading-room design QA

final result: passed

Source visual truth: `/workspace/scratch/327bb0b2b90e/upload/IMG_7929(2).jpeg` (Home), `IMG_7934.jpeg` (Library), `IMG_7932.jpeg` (Reader). The latest user direction adds burger navigation at every web width, uses “Library”, and puts fullscreen near the lower reading controls.

Implementation evidence: `web/qa-evidence/design/webkit-390-no-preference-{home,library,reader}.png` and `chromium-1440-no-preference-{home,library,reader}.png`. Full comparisons: `web/qa-evidence/design/comparison-{home,library,reader}.png`.

## Normalization and states

Sources are 709 × 1536 pixels, normalized to 390 × 844 CSS pixels for comparison. Mobile implementation captures use 390 × 844, deviceScaleFactor 1; desktop uses 1440 × 900. Reference and implementation are placed next to one another in the comparison inputs. Both use the real Computer Science Essentials PDF at page 1. The reference Reader depicts listening; the initial implementation capture is idle. Audio state is live and is not simulated for visual matching. The actual PDF text is retained rather than replaced with mock prose.

## Comparison history

- P2, Home: the first layout pushed the lower navigation partly below an 844px phone viewport. Reduced mobile resume spacing and cover size, retained the large nook artwork, and recaptured. The Continue action, import action and bottom navigation now fit at 390 × 844.
- P2, Library: import tile baseline was 8px lower than the book cover. Removed the extra import margin and recaptured. Both dividers now align.
- P2, Reader: the inherited entrance translation moved the viewport-sized frame briefly. Disabled that frame animation. The reading region reserves space above the footer; the regression test reads both bounding rectangles atomically.
- Capture readiness: an early Home capture preceded completion of the window artwork. The visual journey now waits for rendered image pixels before capture. The rainy window is present in the final comparison.

## Required fidelity surfaces

- Typography: existing Gabarito UI and Literata reading fonts retained. Headings and controls use compact responsive sizes. Titles wrap; imported filenames remain live text and accessible through the book control. The book's repeated document heading is omitted from the rebuilt reading view without changing listening sentence indexes.
- Spacing: selected nook/continue flow and cover/import Library composition retained. Desktop uses available width for the nook and current book, and keeps chapters/notes beside the Reader. Mobile is a single column. Fullscreen is in the lower footer as requested.
- Colors: existing sage, forest, warm cream, red and document palettes retained. The paper frame uses cream; the Reader header/footer use forest. Existing contrast contracts pass.
- Imagery: original nook, rain and tea assets retained with the window moved right. New optimized denim cover artwork supports live document titles. Phosphor supplies the new standard UI icons. No flattened screen image is used as an interface.
- Copy: “Your library”, “Continue reading”, “Import a PDF”, “For reading” and “Original page” match the intended flow. Sample count comes from the actual remaining samples rather than a hard-coded five.

Focused comparisons inspected the Home resume region and the Library cover/import baseline at normalized mobile density. The Reader comparison inspected mode controls and the lower footer. No actionable P0/P1/P2 differences remain. The original source artwork differs slightly from the generated scene's window proportions; retaining the original live scene is intentional.

## Interaction evidence

The dedicated reading-room journey passes Chromium desktop, Chromium mobile reduced motion, WebKit mobile normal motion, and WebKit 320px reduced motion: Home → Library → Reader; case-insensitive search and no-results state; collection filters; import affordance; saved page progress; reading settings; original PDF mode; fullscreen enter/exit; lower fullscreen geometry; footer not overlapping the text; no page exceptions.

Separate existing suites cover notes, explanations, exact source search, study, trails, real PDF imports, original PDF rendering and zoom, horizontal screen pagination, gesture cancellation, pull-down exit, haptic fallbacks, restored bookmarks, live reduced-motion changes, and source/voice lifecycle behavior. Browser-console checks found no application exceptions. PDF.js reports absent platform PDF fonts in headless WebKit and the browser can report unused font preloads; those are environment/performance warnings, not application exceptions.

## Code review follow-up

Completed Compound Engineering review receipt: `20261031-151841-e873ebbc` (seven reviewer perspectives, three validated findings). All three findings were applied: the fullscreen trigger remains mounted to preserve keyboard focus; the internal reading scroll offset is saved/restored for the same source page; and page-reset coverage now establishes a real nonzero scroll position before turning the page. The dedicated Chromium/WebKit journey verifies all three fixes. No unresolved review findings remain.

Portable visual evidence: `docs/design/reading-room-preview.webp`. The new cover is deliberately consistent across Home and Library for the same document.

## Follow-up polish

No blocking follow-up. Verify physical-device feel for gesture/haptic timing during ordinary release acceptance; the automated checks exercise browser behavior and fallbacks.
