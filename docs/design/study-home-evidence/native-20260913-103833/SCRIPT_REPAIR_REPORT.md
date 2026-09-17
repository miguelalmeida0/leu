# Study verification runner repair — 2026-09-13

Only scripts/verify-study-home.sh changed in executable project source. Product code, UI tests, models and design are untouched. The scope snapshot confirms 387 product/test/package files are byte-identical.

## Exact script failure

The default iteration populated extra with two test selectors. AX1 set extra=(). On macOS /bin/bash 3.2.57, expanding that empty array with set -u raises "extra[@]: unbound variable". Reproduced directly with installed Bash. The expansion failed before xcodebuild started AX1. Setting +e does not turn off nounset.

The repair uses an always-nonempty selected_tests array, initialized with ShelfStudyHomeUITests, then appends default-only selectors. No disabling set -u and no empty-string test argument.

## Completed phases before failure

| Phase | Observed result |
|---|---|
| Palette checks | PASS, 55/55 |
| Night Field source checks | PASS |
| Study interaction source checks | PASS |
| Project/source validation | PASS |
| Native app build | PASS, build.log contains BUILD SUCCEEDED |
| Requested simulator boot | PASS, already booted |
| Default content size | large |
| Default native tests | Completed: 4 PASS, 1 FAIL, 0 skipped |
| default.xcresult | Written and preserved |
| Default summary export | Complete |
| Default attachment export | Complete; all 76 manifest files exist |
| AX1 size selection | Complete; accessibility-medium recorded |
| AX1 tests / result / screenshots | Did not start |

Identity: iPhone Air, simulator A248FB9E-B969-4CF6-A0ED-B2013A3C60A6, iOS 26.5 build 23F77, arm64.

## Native journeys

| Test | Result |
|---|---|
| test32LearnTodayCreatesLocalStudySession | PASS |
| testContinueUsesRealRememberedSourceAndReturnsToReader | PASS |
| testEmptyStudyFieldsAndExistingDestinations | PASS |
| test48ProgressReopensAfterScrollingAndBothTabsWork | PASS |
| test49StudySecondaryButtonsOpenRealDestinationsAndCollapse | FAIL |

The sole recorded failure is ShelfUITests/ShelfStudyInteractionUITests.swift:33. Interview Mode navigation appeared, then app.buttons["Start interview"].exists failed. The test stopped before its subsequent More-tools checks. It has not been weakened, changed, or rerun.

## Reused visual evidence

Byte-identical copies of actual simulator PNGs, inspected in this task. Original filenames, hashes, timestamps, device IDs and test names are in captures/manifest.json.

1. [Study empty](captures/01-study-empty.png)
2. [Study populated](captures/02-study-populated.png)
3. [Fading](captures/03-fading.png)
4. [Blind Spots](captures/04-blind-spots.png)
5. [Reconstruction Labs](captures/05-reconstruction-labs.png)
6. AX1 Study: not yet captured.

Fading and Blind Spots show their real empty states. Populated Continue comes from Remember on the real React Notes sample; its source round-trip passed. No invented data, image synthesis, resizing or compositing was used.

## Missing stage recovery

Run from the checkout:

~~~sh
bash scripts/verify-study-home.sh --resume docs/design/study-home-docs/internal/evidence/native-20260913-103833
~~~

This skips completed static verification/build/default testing, reuses default.xcresult and existing exports, and runs only missing AX1 tests with test-without-building against .build/study-home. Compiled app and UI-test runner exist. No fallback rebuild is performed if they are missing.

The exit status retains the default failure even if AX1 passes. Existing failed bundles are preserved and not silently retried. Missing summaries/exports are recovered without launching the simulator.

The repaired resume command was actually attempted in this session. It reused default evidence, then failed at the missing stage's bootstatus with CoreSimulator POSIX 61 Connection refused. No new build/default tests/AX1 tests ran. See script-repair-resume.log. AX1 remains blocked, not a claimed pass or app failure.

## Script verification

Three control-flow regression scenarios pass under /bin/bash 3.2:
- resume runs only AX1 with test-without-building and carries prior exit 65;
- existing results trigger no Xcode/simulator calls;
- missing summary/attachments trigger export only.

These scenarios stub external commands strictly to test the shell runner; they do not count as native iOS evidence. See script-repair-regression.py and .log. Shell syntax also passes.

## Remaining

- Run missing AX1 and inspect/export its real captures.
- Native suite remains FAIL because of test49. Product/test repair is outside this task's script-only scope.
