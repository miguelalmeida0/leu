# Leu Native V23 — Gallery Minimalism Redesign

V23 is a full native UX/UI redesign of Leu around the selected **Gallery Minimalism** direction. It is not a theme-only patch.

## Visual system

- Light-first warm ivory / stone / paper surfaces.
- Editorial serif hierarchy with system sans reserved for utility metadata.
- Restrained semantic accents: archival ochre for source/marks, olive for knowledge/progress, oxblood for decisive actions.
- Smaller radii, hairline dividers, flatter list rows, fewer decorative containers.
- Book covers remain distinct physical objects; utility surfaces no longer default to dashboard cards.
- The cold-open / resume surface contains **no tree, foliage, leaf artwork, or tree-shadow motif**. Its atmosphere is abstract paper/light only.

## Product structure

- One persistent navigation level: **Library / Study / Trails**.
- Favorites and Recents are Library filters; Tags & Marks and Settings live inside Library rather than a second tab bar.
- Trails is the single user-facing ordered-path concept; Topic Chain internals no longer expose a competing creation flow.
- Connected passages use one common-case **Save connection** action, with relationship type and Trail placement available as later refinement.

## Reader

- Compact editorial top chrome and simplified bottom rail.
- Explicit PDF/SwiftUI viewport frame repair for Read and Original clipping regressions.
- Deterministic Read-mode extraction repair for known spacing seams such as `JAVAS CRIPT`, `MENTALMODELS`, `INONEBREATH`, letter-spaced headings, and leaked internal reference IDs.
- Search jumps leave a visible **Back to p. N** breadcrumb.
- Question/source and cross-library travel expose a visible return affordance rather than relying only on back-stack semantics.
- Reading Settings is rebuilt as a flatter Gallery Minimalism surface; Original PDF defaults to the warm paper surround on a fresh install.

## Marks, study, progress, voice

- Reader study drawer is now **Your Marks** and Read-mode marks store a real source excerpt instead of an empty `Whole page saved` placeholder.
- Study home uses progressive disclosure rather than showing every learning subsystem at once.
- Questions, answer review, session completion, Progress Now/History and Trails share the same editorial system.
- Learning State is presented as **Progress**; history is **Progress History / Understanding Time Machine**.
- Voice and listening inherit the same light-first design system while retaining the local technical-speech compiler.

## Regression contracts added/updated

V23 static/native QA now guards:

- Gallery Minimalism design tokens and light-first presentation.
- the no-tree/no-foliage resume invariant;
- one-tier navigation;
- visible source-return and search-return affordances;
- single Trails creation flow;
- one-action connection saving;
- source-bound Learning OS accessibility contracts.

## Verification before packaging

- Structural/source/project validation: PASS.
- Swift syntax parsing across app, unit tests and UI tests: PASS.
- Learning/Knowledge/Voice/offline/privacy architecture checks: PASS.
- Native UI-test contract and SwiftUI compile-contract checks: PASS.
- Gallery Minimalism release contract: PASS.
- Portable ShelfCore suite: **182 tests, 0 failures**.
- Voice 1000-block / 3000-segment performance benchmark: **2.47s**, under the unchanged 3.0s gate.

Apple SDK compilation, PDFKit integration tests and XCUITest are intentionally left to the included macOS QA gate; Linux cannot truthfully certify Apple frameworks or iOS Simulator behavior.

## V23.1 convergence note

The Apple PDF readable-text seam discovered during V23 native certification is fixed in `PATCH_V23_1.md`.


## V23.2 convergence note

The remaining Apple XCUITest semantic selector failures discovered during V23.1 certification are repaired in `PATCH_V23_2.md`.
