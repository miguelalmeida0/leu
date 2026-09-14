# Leu Native V23.2 — Apple XCUITest Semantic Convergence

V23.2 keeps the Gallery Minimalism redesign and fixes the remaining Apple-runtime QA contract exposed by V23.1.

## What changed

- Preserved the redesigned Reading Settings labels (`Vertical` / `Horizontal`) and migrated XCUITest to the actual segmented-control contract.
- Added stable semantic identifiers and atomic accessibility labels to Active Recall and Interview Mode rows.
- Added stable identifiers for Progress now, Progress history, Connections, document topics and idea search menu actions.
- Made the reader source-return action one atomic accessibility element with the exact context label (`Back to question` for Learning source inspection).
- Added a unique `library-tags-back` action so the visible word `Library` is never an ambiguous XCUITest target.
- Strengthened `check-ui-test-contract.py` so old selectors cannot silently return.
- No visual rollback: Gallery Minimalism, one-tier IA, unified Marks/Trails, no-tree resume invariant and visible return paths remain unchanged.

## V23.1 Apple result that led here

- Apple build: passed.
- Portable core: 182/182 passed.
- Apple PDF/viewport integration: 20/20 passed.
- XCUITest: 37/48 passed; 11 semantic selector/round-trip failures remained.

V23.2 specifically converges those native interaction contracts without weakening any assertion.
