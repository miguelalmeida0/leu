# Paged fullscreen reader implementation plan

> For agentic workers: implement inline using superpowers:executing-plans; obtain one fresh whole-change review before promotion.

**Goal:** Replace the rejected vertical reader with fitted, horizontally paginated reading: one swipe/tap turns one screen and never moves the app vertically.

**Architecture:** A fixed visual-viewport shell hosts a three-panel deck. Reading text uses height-constrained CSS columns, preserving selectable text and its sentence anchor; original PDFs fit entirely at 100%, with contained pan when enlarged. Pointer gestures drive horizontal translation and settle exactly one screen. Controls overlay the page and are hidden on entry; centre tap or keyboard reveals them without repagination.

**Tech Stack:** Existing React 19, TypeScript, PDF.js, browser CSS/Pointer Events; no new dependency.

**Spec:** Current user correction and IMG_7919.png. The requested reference is Kindle's paginated side-to-side reading, with a stable page and hidden controls. Safari's own browser chrome remains browser-controlled.

## Global constraints

- Only main/test refs. Work on test; preserve existing untracked QA evidence.
- Preserve Leu fonts, colours, annotations, explanation, original view and listening.
- No vertical scroll surface in fullscreen; pages must reflow at font/viewport changes.
- Native fullscreen where available; visualViewport bounds and safe areas otherwise.
- Respect reduced motion; avoid downloaded UI libraries or page-curl effects.

## Review focus

- A long source PDF page must split across readable screens, with no clipped/missing text.
- Diagonal/vertical touch input must never shift the shell or scroll the background.
- Short drags, cancelled pointers and first/last boundaries must settle safely.
- Rotation, font zoom and keyboard/browser viewport changes must retain the passage.
- Text selection, same-book search, audio follow and quick repeated swipes must not race navigation.

### Task 1: Replace fullscreen scrolling with paginated reading

Files: create web/src/components/paged-reader/{PagedReader.tsx,PagePanel.tsx,usePageGesture.ts,usePageWindow.ts,types.ts,styles.css}; modify Reader.tsx, Prose.tsx, useReaderFullscreen.ts, ReaderLayout.css, store.ts; remove ContinuousPages.tsx.

Interfaces: PagedReader exposes step(direction: -1 | 1) and goToPage(page: number). Props consume doc, source page, mode, zoom, active paper ref, reading state, sentence bookmark and callbacks for source turns, zoom, centre tap and position. Position includes source page, screen index/count, sentence and boundary availability.

- [x] Write failing paginated-reader browser proof with hidden controls, fitted content, horizontal/diagonal gestures and invariant vertical geometry. Observe failure on the current reader.
- [x] Implement viewport bounds/scroll lock and an overlay control shell.
- [x] Implement CSS-column text screens, original fit/pan, three nearby panels, pointer/keyboard/wheel turns and source-page transitions.
- [x] Preserve sentence bookmarks, selection and read-aloud following; keep source routes for search and annotations.
- [x] Verify WebKit 320/390, Chromium desktop/mobile, portrait/landscape, normal/reduced motion. Exercise real mobile Chromium touch input through CDP, plus WebKit gesture and viewport checks.

### Task 2: Integrate verification and ship

Files: web/scripts/*reader*journeys.mjs, browser-journeys.mjs and .github/workflows/web-browser-journeys.yml as needed.

- [x] Replace vertical-fullscreen expectations with the intentional paginated contract, retaining all unrelated journeys.
- [x] Exercise a real long-page PDF fixture, all screens and both source boundaries; verify no text loss, clean exit, reload and error paths.
- [x] Run npm ci, build, existing contracts, Home and browser suites; obtain a fresh source review.
- [ ] Publish only the focused change to test. Wait for web-release-gate and portable-core on push and PR; then promote and verify live interactions.

## Local verification and review

- The initial regression failed against the former continuous reader (no paged deck). The completed suite passes all six viewport/motion cases plus Chromium and WebKit extraction-failure fallback.
- Actual Chromium CDP touch proves finger-following translation, diagonal turns, swipe-to-pinch recovery and compatibility-click containment. WebKit verifies source traversal, resize, original fit/pan, viewport containment and reduced motion through real pointer input.
- Every extracted sentence in the dense three-source-page fixture appears during traversal. Fullscreen notes, same-book search, saved location, PDF zoom and clean exit pass in the existing four browser journeys.
- Fresh whole-change review found and fixed touch click-through, interrupted-pinch offset, text-error blocking of Original, safe-area gutters and reduced-motion settle state. No remaining substantiated blocker; physical iPhone browser chrome and native long-press selection were not certified by emulation.
- Local clean install and build pass. The optional server CUDA download is disabled with the dependency's documented ONNXRUNTIME_NODE_INSTALL_CUDA=skip setting; browser WASM voice assets remain included. All 26 existing artwork, voice and accessibility contracts pass. Home motion journeys and CI release gates are also required before production promotion.
