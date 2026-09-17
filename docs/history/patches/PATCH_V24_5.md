# Leu V24.5 — Release Interaction & Complete Test Sweep

## Status

Source repair and test candidate. **Not an Apple-certified release.** No V24.5 Xcode build or iOS Simulator test was executed in this Linux environment. All local results below were actually run; the native run remains required.

Baseline archive: `Leu-Native-V24.4-Lens-Compile-Repair.zip`.
SHA-256: `0bb1fbd4cc43c283311f277a32e11436f0aba4814c1a10e602dd6bdfbcdee2a8`.

## What the supplied Mac run proves

The supplied V24.4 summary reports BUILD SUCCEEDED, 204 core tests with no failures, 20 Apple/PDF tests with no failures, and passes for tests 50, 51, 52 and 53. It stops at test 54. The sensitive Study gate and the full remaining UI regression suite were not reached. It is incorrect to describe those unexecuted tests as green, or as known failures.

The failed trace locates `release-accessible-action` at approximately `(39.8, 785.9, 100.1, 48.8)`. Its bottom is 834.7, while bottom navigation begins at 820 and the test's inset unobscured viewport ends at 812. The control exists and reports hittable, but is not fully visible. The strict test correctly rejects it.

The previous `SessionCompleteView` appended a 130-point drawing Canvas and its action row beneath the emotional choices, inside the main summary ScrollView. The Canvas recognizes `DragGesture(minimumDistance: 0)`. The helper calculates an upward-scroll start at `(210, 664.8)`, inside the logged Canvas `(40.2, 644.3, 340.3, 130)`. The log does not record native gesture arbitration, so this is a source/geometry diagnosis of the scroll/draw conflict, not a claim to have observed a recognizer callback. Merely accepting `isHittable`, weakening containment, or increasing retries would hide the defect.

## Product repair

`SessionCompleteView` now displays either the existing summary or a focused `ReleaseSurface`, using the existing `releasePresented` state. There is no new modal, NavigationStack, root navigation owner, or Progress rewrite. The original session remains available while Release is open.

The Release canvas and descriptive content scroll separately from the controls. A bottom `safeAreaInset` reserves space for native Release, Continue and I'm done buttons above the application's existing bottom chrome. Their labels include at least 44-point hit targets. Accessibility text sizes use vertically stacked secondary actions. The canvas does not own or wrap the controls' gestures.

The accessible Release action works with or without a drawing, clears the drawing, and transitions to an actual “Better?” result. Continue returns to the same completed session. I'm done finishes it. Drawing is ephemeral, never persisted or used as an emotion score, and is capped at 2,048 points / 64 strokes. Separate strokes do not receive artificial connecting lines. Invalid coordinates are rejected and points are clipped to the canvas. Late drawing events cannot recreate a released drawing. The release haptic runs only on the first completion transition.

The irritated and drained choices use vertically arranged controls to avoid the old tight three-button row. Completion exits no longer perform an unordered, swallowed `saveResumeStudyContext` write. They use the existing ordered checkpoint path, await its result, retain the screen on a save error, and reject a stale exit if a different session has started. No persistence schema is changed.

## Speech compilation performance

The first local run against unchanged V24.4 core source passed 203/204 tests, failing only the unchanged repeated-technical-text performance gate at **3.611906194 seconds** against **less than 3 seconds**. That red result is preserved in `core-tests-before-optimization.log`.

The compiler was repeatedly running the same cleaning/technical-normalization pipeline for identical source segments. It now uses a **compilation-local, bounded normalization cache**: at most 256 entries and 4,096 combined UTF-8 source/output bytes per entry. No cache survives the compile call. Source text and code/prose mode form the key; dictionary and code-mode arguments are fixed for that call. Every source mapping, document/page/range, segment identity, kind and prosody is still constructed independently.

The normalization rules, source splitting, source offset calculation, pronunciation dictionary, speech backend and benchmark assertion are unchanged. Eight new tests check reuse, code/prose separation, bounded storage, segment parity with independent compilation, pronunciation/code-mode changes between calls, UTF-16/source identity, empty output and concurrent dictionaries.

The resulting full core run passed **212/212 tests**. The same original 1,000-block / 3,000-segment benchmark measured **0.06669191 seconds**. This measurement is for that repeated-text compilation workload. It is not a claim about neural synthesis speed, unique-prose throughput, or audible voice quality. There was no performance retry-until-green; the passing run follows an actual production optimization.

## Complete test sweep instead of hidden downstream failures

The old shell `set -e` stopped after a failed feature gate, preventing visibility into downstream regressions. QA still stops if source checks or the initial Apple build fail, but after a successful build it attempts every independent test batch even if a prior test batch fails. It retains the first nonzero test exit code.

The planned native inventory is exhaustive and disjoint:

| Batch | Unique tests |
|---|---:|
| Apple/PDF integration | 20 |
| Observed Release regression: test 54 | 1 |
| Other V24 journeys: 50–53, 55–56 | 6 |
| Sensitive Study regressions: 36, 39, 40, 48, 49 | 5 |
| Remaining original UI regression | 45 |
| **Total UI tests across the four UI batches** | **57** |

No focused test repeats in a later batch. The baseline inventory locks the existing 55 UI and 20 Apple test names against accidental removal. The verifier rejects absent stages, missing outcomes, skipped tests, unexpected tests in a batch, duplicate executions, and failed-then-passed sequences. A test failure cannot become success because subsequent tests or diagnostics export succeeded.

The QA wrapper always includes a coverage report, including on red runs, and copies the real result to the clipboard. Diagnostics include `suite-plan.json`, `suite-results.json`, the full log, coverage report, commands, results and available native attachments. No model assets are downloaded automatically. Orchestration unit tests use explicit stub command executables only to test runner behavior; they are not counted as native UI executions.

## Native acceptance

All original test names remain. Test 54 is strengthened: it requires the actual pinned buttons to be fully inside the unobscured viewport and their control dock **without scrolling**, performs one native tap, verifies the completed result, returns to the summary and finishes the session.

Two native regressions are added:

- **55:** completes a real study round, draws with an actual drag, verifies the drawing changed, checks controls remain visible, releases, exits and relaunches without restoring a drawing or finished session.
- **56:** completes a real round, chooses Drained, saves/exits, captures a real history-event identifier, relaunches, and verifies that same event still exists.

Those new tests have not been executed on Apple here. Existing native tests 00–53 have unchanged method bodies; test 54's acceptance is extended rather than disabled or reduced.

## Local verification

| Check | Executed result |
|---|---|
| Portable core | **212 tests, zero failures** |
| New cache tests within core | **8 passed** |
| New Release/policy/runner regression suite | **23 tests passed** |
| Real production Release state + recorded-geometry arithmetic | **27 checks passed**, within the 23-test suite |
| Existing Study repair tools | **27 tests passed** |
| Settings/compiler-summary repair tests | **14 tests passed** |
| V24.2 interaction/recovery policy tests | **17 tests passed** |
| Root compile/lifecycle regression suite | **13 tests passed**, including 30 adapted lifecycle checks |
| Lens projection regression suite | **11 tests passed**, including 26 projection/action checks |
| Existing delivery/launcher tools | **15 checks passed** |
| Actual annotated LearningModel typecheck | Passed with portable platform dependencies |
| LearningModel recovery logic | **9 checks passed**, Observation/PDF/UI adapters excluded |
| Structural/project and source policies | Passed; **462 project objects** |
| Swift source/test/harness syntax | **300 files parsed** |
| V24.5 Apple build / native tests | **Not executed here** |

The harnesses do not instantiate SwiftUI, validate native gesture arbitration, or certify an Apple SDK. Logs retain their individual scopes and earlier failures. The new Release harness initially needed an actor annotation and an explicit CGFloat constant in the harness itself; those corrections were made before its passing run. No production assertion was relaxed.

## Preserved scope

Byte comparisons confirm that RootView, all Reader and Lens source, Knowledge, learning/semantic persistence, app-level Voice/Supertonic implementation, all Apple tests, design tokens and bundled resources are unchanged from V24.4. Only the completion/Release UI and portable speech normalization reuse change production behavior. Settings and project marketing-version labels are updated to 24.5. Xcode membership adds the two app files and two native UI test/support files; synchronization is idempotent.

The no-tree Resume screen remains unchanged. Existing library, annotation and study storage namespaces, signing identifiers and migrations are preserved. No user's local project, installation, account or repository was modified from this environment.

## Mac command

```bash
cd "$HOME/Downloads" &&
unzip -oq "Leu-Native-V24.5-Release-and-Complete-Test-Sweep.zip" &&
cd "LeuNativeV24_5" &&
SHELF_QA_LOG=qa-v24-5.log ./scripts/qa-and-copy.sh
```

Expected acceptance: Apple build success, 212 core tests, 20 Apple tests, all 57 UI tests, no omissions/skips/retries, final exit 0. The summary copies automatically; do not append another `pbcopy` that overwrites it. V24.5's native result remains pending until this executes on the Mac. Physical-device haptics, VoiceOver experience and Supertonic listening quality remain separate acceptance work.

## Primary API references

- Apple SwiftUI, safeAreaInset: https://developer.apple.com/documentation/swiftui/view/safeareainset(edge:alignment:spacing:content:)
- Apple SwiftUI, DragGesture: https://developer.apple.com/documentation/swiftui/draggesture/
