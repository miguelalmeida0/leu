# Leu V24.5.1 — Release state harness compile repair

## Status

Source repair. **Not an Apple-certified release.** No Xcode build or iOS Simulator run was executed in this environment. The change is confined to one validation harness plus its manifest entry; no application source, no test inventory, and no policy contract was modified.

## The failure

`ReleasePolicyTests.testRealPortableReleaseState` failed at the compile step, before any assertion ran:

```
ReleaseStateHarness.swift:35:41: error: operator function '==' requires that 'CGPoint' conform to 'Equatable'
ReleaseStateHarness.swift:40:23: error: type 'CGPoint' has no member 'zero'
ReleaseStateHarness.swift:40:34: error: type 'CGSize' has no member 'zero'
ReleaseStateHarness.swift:72:30: error: argument passed to call that takes no arguments   // CGRect(x:y:width:height:)
```

Because `qa-native.sh` runs under `set -e`, this single non-zero exit aborted the sweep before the native compile gate and `run-qa-suites.py`. The reported `FAIL: complete native coverage was not established` was a consequence of the truncated log, not a separate defect.

## Root cause

The test compiles exactly two files on their own:

```
swiftc -swift-version 5 -strict-concurrency=complete -warnings-as-errors \
    Shelf/Learning/ReleaseInteractionState.swift \
    validation/v24-5/ReleaseStateHarness.swift -o release-tests
```

`CGPoint`, `CGSize` and `CGRect` are declared as plain C structs and reach the file through `Foundation`. Their *conveniences* — the `Equatable` conformance, `.zero`, `CGRect(x:y:width:height:)`, `midX`, `contains(_:)` — live in the CoreGraphics overlay, which this invocation never imports. The bare structs supply only a memberwise initializer and stored-property access, which is why `CGRect`'s only visible initializer took no arguments and why `==` found no conformance.

This explains the error distribution precisely. `ReleaseInteractionState.swift` uses only `CGPoint(x:y:)`, `.x`, `.y`, `.width`, `.height` and `CGFloat` arithmetic, so it compiled clean. Every diagnostic landed in the harness, on the four overlay-only constructs listed above. V24.5 is the first validation harness to use geometry types at all — `validation/v24-2`, `v24-3` and `v24-4` contain no `CG` references — so the gap had no earlier opportunity to surface.

The Release state machine itself is correct. All 27 assertions were re-derived against a faithful port of `ReleaseInteractionState` before any edit and all 27 hold, including the `(-100, 600) → (0, 160)` clamp, both storage ceilings, and the recorded-geometry replay. Nothing was weakened to make the suite green.

## The repair

`validation/v24-5/ReleaseStateHarness.swift` no longer depends on the overlay:

- `import CoreGraphics` is added under `#if canImport(CoreGraphics)`, declaring the dependency the file actually has and satisfying member-import visibility on Apple platforms.
- The clamp assertion compares components (`clamped?.x == 0 && clamped?.y == 160`) instead of relying on `CGPoint: Equatable`. `CGFloat`'s `Comparable` conformance is already proven visible by the state file's own `min`/`max` and `>=`.
- `.zero` is replaced by explicit `CGPoint(x: 0, y: 0)` and `CGSize(width: 0, height: 0)`.
- The recorded V24.4 frames use a local `RecordedFrame` value type that reproduces `CGRect`'s standardised `minX`/`minY`/`maxY`/`midX` and both `contains` semantics — half-open edges for a point, full containment for a rectangle. The recorded numbers are carried over verbatim, so the arithmetic under test is unchanged and the harness has one deterministic code path on every platform.

Every construct the harness now relies on — `CGPoint(x:y:)`, `CGSize(width:height:)`, `CGFloat.nan`, `CGFloat.infinity` — appears on source lines that the same compiler invocation already accepted without diagnostics.

Assertion count, assertion text, and the `PASS: 27 Release state/recorded-geometry checks` contract asserted by the test are all preserved. File length is 114 lines, inside the 300-line boundary.

## What was deliberately not changed

- `ReleaseInteractionState.swift`, `ReleaseSurface.swift`, `SessionCompleteView.swift` and `ReleaseInteractionSupport.swift` are untouched. All eleven mutation policies in `check-v245-release.py` still reject their regressions.
- No test was removed, renamed, skipped or retried; `baseline-test-inventory.json` and the 57-test UI inventory are unchanged.
- `SOURCE_SHA256SUMS.txt` was regenerated for the one edited file. The other 568 entries were verified to still match byte for byte.

## Verified in this environment

All sixteen policy audits and five Python suites in `qa-native.sh` order pass, including `check-v245-release.py` and 22 of 23 tests in `test-v245-release.py`. `testRealPortableReleaseState`, `test-v243-root-compile.py` and `test-v244-lens-compile.py` require `swiftc`, which is absent here; they are the Mac-side gates.

## Still required on the Mac

`./run.sh --build`, the five non-overlapping native batches driven by `run-qa-suites.py`, and the `verify-qa-results.py` coverage gate. Those remain the only evidence of a green native run.
