# Final AX1 test repair — verification pending

## Root cause

Classification: test scroll-positioning / lazy-realization defect.

Original assertion: ShelfUITests/ShelfStudyHomeUITests.swift:41:
XCTAssertTrue(app.buttons["10 minutes"].exists)

The failing journey expanded the builder and immediately queried a duration button without scrolling past its subject rows. AX1 increases those rows' height. At failure:
- root-content-viewport: y=68, height=719, bottom=787;
- TIME group: y=932;
- duration LazyVGrid: zero-sized accessibility node with no realized buttons;
- Start: y=1128.3, present but off-screen.

The expected control was therefore below the viewport when queried, not renamed or covered by the floating nav. This was not a product accessibility failure: the SAME saved AX1 run's separate builder journey passed after using revealStudyButton through tapStudyButton("10 minutes"). That production trace records the real duration button at y=584.3, height=64.4, enabled=true, hittable=true.

Inspected evidence:
- failure screenshot: ../AX1-attachments/3103462F-6E75-471D-8DA9-E6ACC9FF39BD.png
- failure tree: ../AX1-attachments/574EA39F-81ED-4E63-8443-904B9AD22305.txt
- already-passing builder screenshot: ../AX1-attachments/D4AFF32C-2E96-4F3C-BCAE-AF7786850BAB.png

The passing builder image is prior evidence for reachability, NOT a retest image of the repaired journey.

## Code change

ShelfUITests/ShelfStudyHomeUITests.swift:41–45 adds four lines:
1. Explain the AX1 lazy-grid positioning requirement.
2. Reveal the real native button through the existing measured-viewport scroll helper.
3. Preserve the original existence assertion unchanged.
4. Additionally assert full viewport containment, tappability and navigation clearance.
5. Capture empty-builder-duration-reachable.

The original collapse-state and removed-Start assertions remain unchanged. No fixed sleeps, generic accessibility-node fallback, fixture output, production changes, or weakened coverage.

scripts/verify-study-home-ax1-repair.sh is the targeted verification runner. It runs only the failing journey with incremental test compilation; only after exactly 1/1 passes with zero skips does it run the 4-test AX1 suite with test-without-building. Default is never selected. Each run gets a new evidence subdirectory, preserving original bundles.

## Verification

- UI-test source typecheck: PASS.
- Study interaction source contract: PASS.
- Runner shell syntax: PASS.
- Single native retest: BLOCKED before XCTest. Actual attempt run-20260913-113916/simulator.log reports CoreSimulator POSIX 61 Connection refused.
- Full AX1 rerun: correctly not started because the prerequisite single retest could not execute.
- Latest completed native AX1 remains 3/4, one failed, zero skipped.
- Default: existing 7/7 GREEN, zero failures/skips; all saved default evidence hashes preserved.
- No production files changed. See scope.json.

## Execute remaining stages

~~~sh
cd /Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast
bash scripts/verify-study-home-ax1-repair.sh
~~~

The script restores the previous text size on exit and exports single/full summaries and attachments under ax1-repair/run-<timestamp>/. The new repaired screenshot will be named empty-builder-duration-reachable in the exported manifest; no new screenshot currently exists.

## Unresolved

1. Single AX1 retest needs actual simulator execution.
2. If green, the four-test AX1 run and repaired screenshot inspection remain.
3. Final 4/4 cannot be claimed until those results arrive.

ClaudeSessionFinal was not touched or integrated.
