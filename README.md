# Leu Native V24.5 — Release Interaction & Complete Test Sweep

An **Apple-test candidate**, based on the V24.4 build that passed native compilation, 204 core tests, 20 Apple/PDF tests, and native V24 journeys 50–53. Its remaining observed failure was the inaccessible Release action in test 54. V24.5 has not been run with Xcode/iOS Simulator here.

## Run the complete Mac QA

```bash
SHELF_QA_LOG=qa-v24-5.log ./scripts/qa-and-copy.sh
```

After the Apple build succeeds, QA attempts all independent suites, even if a test fails. The first failure remains the exit status. Every native test runs **once**: 20 Apple/PDF tests, then test 54, six other V24/emotional journeys, five historically sensitive Study tests, and 45 remaining UI tests. Those non-overlapping batches constitute the complete **57-test UI inventory**; they are not 57 tests plus additional repeated gates. The original 55 test names are locked against accidental removal. There are no skip/retry flags.

The portable core now contains 212 tests (the previous 204 plus eight normalization-cache regressions). The summary, actual exit code, and diagnostics path are copied automatically with `pbcopy`. Do not append `tail | pbcopy`. The run plan, stage results and coverage report are included in diagnostics. Previous workspaces and logs are not deleted.

## What changed

Release is a focused, in-place surface, not a drawing canvas appended to the scrolling summary. Its action/continue/exit controls reserve their own safe-area space, outside the drawing gesture. Completing Release clears the ephemeral drawing and shows “Better?” with real Continue / I'm done actions. All exit controls remain available without drawing. Large text uses a vertical secondary-action layout. Summary exit waits for an acknowledged checkpoint.

Speech compilation uses a bounded, compilation-local cache for repeated normalized text. It rebuilds every source mapping and segment independently, does not cross dictionary/code-mode changes, and does not change Supertonic or the technical-normalization rules. The original 3-second benchmark is unchanged.

Read `PATCH_V24_5.md`, `docs/V24_5_CODE_CHANGES.diff`, and `evidence/v24-5/` for scope and verification. Learning/semantic persistence, Reader, RootView, Lens, Knowledge, app-level speech backends, design tokens and bundled resources are unchanged from V24.4. The no-tree Resume invariant remains.

## What is not certified

Portable logic tests and syntax parsing do not certify SwiftUI layout, iOS gestures, Xcode compilation, physical haptics or listening quality. The native 57-test run must still execute on your Mac. Supertonic synthesis/listening acceptance remains separate; checking its Settings controls is not an audio-quality test. No model asset is bundled or downloaded by this QA workflow.
