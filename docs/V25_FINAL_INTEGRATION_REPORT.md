# V25 final integration — runtime verification blocked

2026-09-12. Convergence is **not complete**. The supplied local run proves BUILD SUCCEEDED and 243/243 core tests passed before this patch. It reports 26 Apple/PDF methods with nine assertion failures across three methods, plus the named UI integration failures. No current native pass is claimed.

The supplied log is preserved in `recovery-docs/internal/evidence/v25-final-integration/supplied-qa-v25-recovery.log`; the original `qa-v25-recovery.log` was not overwritten. The previous convergence report describes an earlier patch and remains historical evidence.

## Changes and limits of the diagnosis

### A — spatial reconstruction

The supplied UI tree contains corrupted source-derived labels, such as `Memory state for interfa e`, while PDFKit's original text displays complete sentences. This establishes an extraction problem upstream of Study; it does not by itself identify which spatial operation corrupts the text.

Two bounded repairs address unsafe boundaries in that path:

- `PDFSpatialTextExtractor` pairs character bounds with `PDFPage.string`. It uses whole-page attributed font indices only when the attributed text exactly matches that string, otherwise obtaining attributes from the corresponding selection range. This avoids assuming that two independently produced text representations have identical offsets.
- `PDFLineGrouper` uses font size, rather than the smallest glyph's ink height, for vertical tolerance. Periods and other small punctuation previously received disproportionately tiny tolerances. Equal-x ordering now has a deterministic source-index tie-break.

These are **unverified repairs**, not observed resolutions of the failing fixtures. The simulator is unavailable here, so no new actual glyph output can be reported. Numbered-list classification, code precedence, furniture suppression, hyphen handling, and semantic rules were inspected and left unchanged: the numbered-list regex already accepts `1.` / `2.`, and numeric furniture suppression already requires margin geometry. Fragmentation can prevent those correct downstream rules from seeing an intact line.

The three existing tests now request diagnostics containing source text, attributed-string alignment, each glyph's index/text/CGRect/font size, y-band membership, spatial lines, classified lines, and final blocks. Their assertions are unchanged.

The byte test additionally compares an independent control document after repeated serialization, `page.string`, and `page.attributedString`, then prints the first differing offset and surrounding bytes after extraction. **The original byte equality assertion remains.** Neither source mutation nor metadata serialization has been proved as the cause; that failure remains unresolved. The extractor contains no PDF write/annotation mutation, but that source audit does not establish PDFKit's serialization behavior.

### B — extraction/cache/Study/Lens handoff

An analysis previously carried no extraction version. Therefore a book with current semantic and analyzer versions could retain corrupted spatial extraction indefinitely. The persisted `DocumentAnalysis` now has an optional `extractionVersion`; old records decode as absent and require reindexing. The PDF adapter's version is 3, recorded on successful analysis and checked both for extraction checkpoints and completed analyses. The semantic compiler version and question identities were not changed.

Opt-in diagnostics now expose:

1. Extracted block/character counts per document/page.
2. Claim and quiz-truth counts; generated question attempts and accepted questions. “Generated” counts realized forward/reverse candidates before admission, not accepted bank entries.
3. Bank/object counts after the repository successfully saves and returns its snapshot.
4. Question-bearing planner candidates, planned question activities, active question IDs, and rendered QuestionCard ID.
5. Checkpoint question IDs, persisted bank count, and restored question binding.
6. Lens source passage, proposition count, plain-meaning sentences, projected facts, and row appearance events.

The runtime location where a positive count becomes zero is **not yet measured**. The quality floor, truth gating, distractor checks, realization rules, ranking, planner behavior, and confidence layout are unchanged. `SemanticQuestionCompiler` has DEBUG counters only. No fixture facts or questions were inserted.

### C — gesture delivery and navigation

`PageTurnPolicy.swift` and all 22 policy tests are unchanged. The driver previously attempted axis locking only in `gestureRecognizerShouldBegin`; an undecided policy could never advance during movement. The driver now retains the actual touch-down position in the fixed viewport coordinate system, uses that displacement for initial arbitration, initializes pan travel at begin, and feeds subsequent movement into the unchanged locking policy. Already locked axes retain their existing behavior.

Diagnostics cover touch receipt/hit target, mode/flow, fit/zoom/selection, begin eligibility, raw translation and touch travel, velocity, recognizer state, locked axis, preview availability, target delta, cancellation, commit before/after pages, ReaderModel change, and the actual accessibility page-count label observed by XCUITest. Existing descendant-pan failure priority, simultaneous-recognition policy, and native zoom/selection behavior remain. No arrow tap or synthetic page change replaces a drag.

This driver repair is **not runtime verified**. The trace must establish whether recognition, preview creation, cancellation, or synchronization still prevents a turn.

For test25, the supplied log shows the React tile tapped and then only the Library in the failure tree; Reader never appears before the test tries to enter focus mode. The identifier already exists. Tile tap/long-press suppression, route request, and Reader appearance now have distinct trace events. No navigation or identifier repair was guessed; this remains unresolved.

## Verification

| Check | Current result |
| --- | --- |
| Group A: three PDF methods | Exit 1 before execution; CoreSimulator connection/access failure |
| Group B: tests 50, 51, 53, 33, 57 | Exit 1 before execution; same failure |
| Group C: tests 24, 25, 29, 13, 14 | Exit 1 before execution; same failure |
| Portable core runner | Exit 1 before execution; Swift target-info output is `error: permissionDenied` |
| Source/architecture/import/UI-contract checks | 16/16 passed; not native compilation or runtime proof |
| Target runner shell syntax | Passed |
| Inventory | 243 core / 26 Apple-PDF / 59 UI methods, unchanged |
| Existing assertion lines | Unchanged in every modified test file; no skip introduced |
| Full QA | Not run: required targeted-pass precondition is unmet |

Target logs: `recovery-docs/internal/evidence/v25-final-integration/runs/20260912-152605-87025/{A,B,C}.log`. The wrapper reports exit 1 and preserves each group's exit code. Other evidence: `core.log`, `static.json`, `runner-syntax.log`, `baseline.json`, `before-source.zip`, `changed-files.json`, and `integration.patch`.

There is no current BUILD SUCCEEDED, 243/243 assertion result, 26/26 Apple/PDF pass, complete UI pass, or QA exit 0. Permission failures are not test skips or passes.

## Required next run

Run locally where Xcode can access CoreSimulator:

```sh
cd /Users/malmeida/Documents/ChatGPT/Leu/LeuNativeV24_5
bash scripts/test-v25-integration.sh all
```

Each group can also be run individually with `A`, `B`, or `C`. The script retains timestamped logs. UI tests enable local PDF and interaction diagnostics. Inspect the new traces and repair any remaining failures; especially do not replace the byte assertion without the serialization-control evidence. Only after all targeted groups pass:

```sh
SHELF_QA_LOG=qa-v25-recovery.log ./scripts/qa-and-copy.sh
```

## Scope and provenance

23 existing files changed and one targeted runner added, plus this report/evidence. Most changes are diagnostics. Functional changes are limited to PDF text/geometry association, line-band grouping, extraction cache invalidation, and gesture-driver displacement/lock delivery. No feature, semantic architecture rewrite, sample PDF change, UI redesign, or test deletion was made.

This checkout is an untracked directory under the parent repository's unborn `master`; no HEAD commit resolves. Git metadata is read-only in this session. `integration.patch` is a unified diff against the source snapshot captured at intake, **not a Git commit diff**. No commit, push, deployment, or external upload occurred.

API references consulted for the adapter boundary: Apple's [characterBounds(at:)](https://developer.apple.com/documentation/pdfkit/pdfpage/characterbounds(at:)) specifies page-space bounds; [translation(in:)](https://developer.apple.com/documentation/uikit/uipangesturerecognizer/translation(in:)) specifies the requested view's coordinate system. These references inform the implementation; they are not evidence that the failing runtime journeys now pass.
