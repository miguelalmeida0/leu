# Leu V23.11 — Study Disclosure Lifecycle Repair

## Status

A scoped repair candidate, not a certified iOS release. Local source and portable checks pass. Apple SDK compilation and simulator execution of this candidate remain pending.

## What the supplied V23.10 Mac run actually established

The native build passed, followed by 182 core tests and 20 Apple integration tests. The previously failing Progress journeys (36, 39, 40) all passed, as did repeated Progress entry and both tabs (48). Test 49 opened Active Recall, Interview Mode, Connections, Document Topics and Search Ideas, but failed after collapsing More. The full 50-test UI stage was not reached.

The failure is specific and source-correlated. The More button reported `Collapsed`, yet Connections, Document Topics and Search Ideas remained in the accessibility tree at y=402, y=460.3 and y=518.7. Their frames overlapped the following Continue learning and Fading content. Test 49 reported a collapsed control remained hittable.

The previous implementation always constructed those three buttons. It tried to hide them using a zero-height frame, opacity, clipping, hit-testing and accessibility modifiers on their container, followed by an accessibility grouping modifier. On the tested Apple runtime, that combination did not remove the actionable descendants. This report does not assert which individual framework modifier caused the behavior: the observed defect is that hidden controls survived the collapsed state.

## The production repair

Only `Shelf/Learning/Components/LearnSecondaryModes.swift` changes in app production source:

- The three secondary rows are constructed only inside `if model.moreLearningExpanded`. Collapsing removes them instead of retaining invisible controls.
- The zero-height frame, opacity mask, clipping, hidden-container modifiers and extra accessibility grouping are removed. The expanded rows use their natural content height instead of a fixed 190-point ceiling.
- The branch has an identity transition and the toggle no longer animates the entire hierarchy. Only the chevron animates, using the existing motion token and respecting Reduce Motion. The existing selection haptic remains.
- Each secondary action rejects a stale activation if disclosure state is already collapsed.
- The existing typed sheet presenter remains attached to the stable parent, outside the conditional rows. Reopening tools does not replace the presenter.

Progress routing, its Now/History views, recall-session handoff, persistence, Reader behavior, the native interaction helper, design system, resources, and all ShelfCore source/tests are unchanged from V23.10. The no-tree resume invariant remains intact.

## Regression protection

Test 49 retains the original non-hittable assertion and additionally verifies:

1. Initially collapsed tools are absent, not merely invisible.
2. All existing secondary destinations still open through real native Button taps.
3. Collapse removes all three identifiers from the complete accessibility hierarchy, and none remain hittable.
4. Repeated expand/collapse restores exactly one Button for each tool and removes all three again.
5. Connections can actually open after repeated reinsertion, then collapse cleanly after returning.

Waits are condition-based and bounded. There are no sleeps, success retries, direct callback invocations, fixture skips or weakened assertions. The UI inventory remains 50 tests.

A narrow source policy requires all three rows to live within the expanded branch and rejects the old persistent-zero-height pattern, duplicate rows outside the branch, missing activation guard and outgoing fade transitions. Mutation fixtures verify the policy rejects these regressions. This policy is not a Swift parser and is not a substitute for native UI execution.

## QA and diagnostics

The current failing test (49) runs first inside the existing five-test Study gate. Only when it succeeds do 36, 39, 40 and 48 execute, followed by the full 50-test suite. The coverage checker is unchanged and still rejects missing tests, skips and failure-then-retry results. No native test is omitted.

The test teardown now consults `totalFailureCount` rather than treating a not-yet-complete run as a failed run. Apple's XCTest documentation defines that counter as failures plus uncaught exceptions. Before/after interaction screenshots remain. Passing tests no longer intentionally emit enormous `failed-journey` captures.

The clipboard summarizer also waits for each test's actual outcome before including its tree. It retains failure/interruption trees and all pass/fail lines; it drops only trees associated with successful tests. Full logs and diagnostic ZIP contents remain available. Export errors still cannot replace the real QA exit code.

## Executed in this workspace

- 182/182 core tests passed. The unchanged 1,000-block / 3,000-segment voice benchmark took 2.254 seconds against the existing less-than-3-second gate.
- All structural, source import, architecture, privacy, design and native-test source-policy checks passed.
- 269 Swift files, including the simulator-selection utility, passed syntax parsing. This is not Apple SDK typechecking.
- 15 existing tooling checks and 27 repair-tool regression tests passed.
- The disclosure policy rejects the original V23.10 implementation in a before/after source-policy check.
- The new summary parser was replayed against the supplied native log and kept the one actual failed journey and all four passing outcomes, rather than including passing-test failure-labelled trees.
- Byte comparisons confirm no changes in Progress root ownership, its native journey assertions, design resources, Reader source, or core source/tests.

Logs and scope comparisons are in `docs/internal/evidence/v23-11/`. The exact scoped code diff is `docs/V23_11_CODE_CHANGES.diff`. Historic patch notes describe earlier candidates, not certification of this one.

## Native release acceptance

```bash
SHELF_QA_LOG=qa-v23-11.log ./scripts/qa-and-copy.sh
```

Required: build success, 182 core tests, 20 Apple tests, all five focused Study tests, all 50 UI tests, no skips, final exit 0. The clipboard summary and local diagnostic ZIP are produced on failure too. Physical iPhone touch, VoiceOver, visual fidelity, voice and haptic quality remain separate device acceptance checks.

## Documentation consulted

- Apple, `XCTestRun.totalFailureCount`: https://developer.apple.com/documentation/xctest/xctestrun/totalfailurecount
- Apple, SwiftUI transitions: https://developer.apple.com/documentation/swiftui/transition
