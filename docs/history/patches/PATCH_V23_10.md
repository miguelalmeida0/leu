# Leu V23.10 — Study Interaction Repair

## Verification status

**Repair candidate, not an iOS-certified release.** The supplied V23.9 Mac log shows a successful build, 182 passing core tests, 20 passing Apple tests, and failures in all three Progress gate tests. V23.10's native build and UI tests have not been executed in this Linux workspace.

## What the full log establishes

In every failing Progress journey, XCTest queries for a Button, falls back to an `Any` query, resolves `learning-progress` as `Other`, and taps that element. No scrolling takes place before those taps. The subsequent heading lookup times out.

The production `LearnSecondaryModes` component placed `.accessibilityElement(children: .ignore)` after each Button, then supplied a label and identifier without preserving its native control representation. Apple's `AccessibilityChildBehavior.ignore` documentation states that this creates a new accessibility element without initial properties. The shared test helper accepted the replacement node as an action target.

This is a concrete accessibility-contract defect. It is **not** sufficient to conclude, from the log alone, exactly where each physical tap landed. Earlier Active Recall/Interview traces also used `Other` successfully; that counterexample is why this report does not claim that every `Other` tap necessarily fails. A missing destination heading did not justify the previous repeated navigation rewrites.

## Production repairs

- Study rows and More retain their native Button semantics. The replacement `ignore` grouping has been removed; existing labels, hints, identifiers, styles and callbacks remain.
- The real Button label supplies a full-width rectangular hit area and minimum height.
- Root-owned Progress routing is retained. It has not been moved to another presenter or container.
- A separate source-level defect is repaired: when Progress starts a recall session, RootView now reveals the Study session instead of leaving the session behind Progress.
- Progress topics without learning objects are disabled until material is available.
- An explicit-self compiler warning in LearningModel's indexing closure has been corrected without changing the language mode.
- The Gallery Minimalism palette, typography, resume imagery, PDF handling and all ShelfCore source files are unchanged. The no-tree resume guard remains in place.

## Acceptance test repairs and additions

The new Study interaction helper targets exactly one **native Button**. It does not fall back to a generic accessibility element. Before tapping it measures the actual viewport and bottom chrome, including notices, scrolls the complete button into that unobscured rectangle and waits for stable geometry. Geometry probes are non-interactive and exposed only during UI testing, following the existing Reader test convention. Every activation is one real tap; no alternate navigation, direct callback invocation, hidden success path or success-until-retry loop is used.

Test 36 still exercises Progress, History, Done and Connections. Test 39 now checks that the *same captured history event identifier* survives a process relaunch, not merely that a Today heading exists. Test 40 now launches an actual non-empty recall activity from Progress. The source-round-trip fixture in test 33 fails explicitly rather than skipping if its required question is absent.

Two new tests cover repeated Progress entry after scrolling, both tabs, all five secondary Study destinations and collapse behavior. The native UI inventory is now **50 tests**. The focused gate contains **36, 39, 40, 48 and 49**, followed by all 50 tests when the gate passes.

## Diagnostics that survive failure

Before/after tap screenshots and control geometry are attached to the native result. Failure accessibility trees are also printed into the log and included in the clipboard summary. An opt-in DEBUG-only trace records activation, route request and rendered-surface event names; it records no PDF passages or notes and changes no application behavior.

`qa-and-copy.sh` exports the current run's native attachments, full log, toolchain information and available action traces into a `Leu-QA-Diagnostics-*.zip` inside the workspace. It does this after a failing test as well as after success. Export errors are reported separately and cannot turn a failing test run into success. The original `.xcresult` remains available when an export fails.

A coverage check refuses a green result unless every expected Apple and UI test is explicitly recorded as passed. Skips, missing tests and failures followed by retries cannot satisfy this check. Actual test exit status and automatic clipboard copying are retained.

## Executed here

- 182/182 ShelfCore tests passed; the unchanged 1,000-block / 3,000-segment voice benchmark measured 2.205 seconds against its existing 3-second gate.
- All structural, import, architecture, privacy, design and source-policy checks passed.
- 268 Swift source/test/package files passed syntax parsing. This is not Apple SDK typechecking.
- 15 existing tooling checks and 17 new repair-tool regression tests passed.
- The trace implementation was compiled and exercised with diagnostics disabled, enabled in DEBUG, and compiled out in a release build.
- The new input policy rejects the V23.9 baseline's replacement accessibility grouping. This is a source-policy regression check, not native before/after execution.

Raw local verification logs and the scoped code diff are included under `docs/internal/evidence/v23-10/` and `docs/V23_10_CODE_CHANGES.diff`.

## Mac execution

```bash
SHELF_QA_LOG=qa-v23-10.log ./scripts/qa-and-copy.sh
```

The acceptance requirement is: native build succeeds; 182 core tests, 20 Apple tests, 5 focused Study tests and all 50 UI tests pass, with exit code 0. Physical iPhone accessibility, visual fidelity, audio and haptics still require device review.
