# Study Home redesign — implementation ready, visual gate open

Date: 2026-09-13
Checkout: /Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast
Requested simulator: A248FB9E-B969-4CF6-A0ED-B2013A3C60A6

## Build and evidence boundary

**BUILD: BLOCKED / FAIL TO EXECUTE.** The fresh xcodebuild attempt exited 74 before compilation: CoreSimulator service access is denied and Xcode cannot read its temporary Package.resolved lock. The log's malformed-package wording wraps that I/O denial; no package manifest was changed. See [build.log](study-home-docs/internal/evidence/build.log).

The four changed views **typecheck successfully against the existing compiled production Shelf module**, using the installed iOS Simulator SDK. All 15 UI-test source files also typecheck. These are limited compiler checks, not a clean native build, simulator run, or screenshot certification.

The earlier successful native contrast build predates these Study edits and does not certify this redesign.

## Implemented app changes

- Shelf/Learning/LearnTodayScreen.swift: compact header; cobalt Continue field; expandable original subject, duration and Start controls; asymmetric paired review fields; one Labs field with numbered native-button rows. AX sizes use one column, growing text and scrollable content.
- Shelf/Learning/LearnTodayScreen+MemorySections.swift: intentional empty states; real timeline title/date and exact existing source route; real due/blind-spot object counts and titles. A populated review button includes the colored padding in its hit area.
- Shelf/Learning/Components/LearnSecondaryModes.swift: compact 2×2 neutral mode controls, one column at AX sizes. Original destinations, More removal semantics and native button identifiers are preserved.
- Shelf/DesignSystem/LeuDesign.swift: semantic Study surface, primary and secondary foreground tokens.

Continue uses the latest real timeline event. A source-bound event opens that source; a source-less event opens existing Progress. An active saved session still enters the existing session branch before the landing page. No remaining-concept count or synthetic progress is displayed. Empty Continue opens the existing Active Recall setup.

Fading and Blind Spots invoke existing startReview(objectIDs:); the repository's existing review limit is preserved. Counts describe learning objects, not invented counts of attempts. Empty review fields are informational. Labs still opens the existing LabScreen.

The reconstruction step-indicator source is byte-identical: confirmed positions retain a green check inside their circles, unresolved positions stay neutral, and the existing progressive check behavior is unchanged.

## Scope guard

[scope-check.json](study-home-docs/internal/evidence/scope-check.json) compares against a snapshot captured before this task's edits:
- exactly four app source files changed;
- 356 other app/package files are byte-identical;
- zero unexpected app changes.

LearningModel, question generation, Foundation Models, Explain Like I'm 10, source grounding, ReviewScheduler, extraction, Trails logic, voice and persistence have no source changes in this task. VIGIA was not modified.

UI helpers now explicitly open the session-controls expander and scroll controls into the existing measured viewport before tapping. Existing behavior assertions remain. Two new tests exercise empty fields and real remembered-source continuation. Xcode source membership was regenerated for the new test file.

## Contrast

**PASS for declared solid pairings:** 55/55 tests, including ten new Study pairings. Study text minimum is 5.09:1; Labs separators are 3.71:1. Calculations use unrounded sRGB ratios from actual Swift tokens.

| Pair | Measured | Required |
|---|---:|---:|
| studyContinueForeground / studyContinueSurface | 8.33:1 | 4.5:1 |
| studyContinueSecondary / studyContinueSurface | 6.93:1 | 4.5:1 |
| studyFadingForeground / studyFadingSurface | 6.54:1 | 4.5:1 |
| studyFadingSecondary / studyFadingSurface | 5.09:1 | 4.5:1 |
| studyBlindSpotForeground / studyBlindSpotSurface | 8.98:1 | 4.5:1 |
| studyBlindSpotSecondary / studyBlindSpotSurface | 6.86:1 | 4.5:1 |
| studyLabsForeground / studyLabsSurface | 12.95:1 | 4.5:1 |
| studyLabsSecondary / studyLabsSurface | 8.59:1 | 4.5:1 |
| signal / studyLabsSurface | 11.12:1 | 4.5:1 |
| separator / studyLabsSurface | 3.71:1 | 3:1 |

These numbers do not establish rendered contrast, clipping or AX1 usability; actual captures remain required.

## Targeted verification

| Check | Result |
|---|---|
| Four changed views / real existing production module | PASS |
| All 15 UI-test source files | PASS |
| Palette math and declared contrast | 55/55 PASS |
| Night Field source checks | PASS |
| Study interaction source checks | PASS |
| Project/source membership and file boundaries | PASS |
| Native capture-script shell syntax | PASS |
| Fresh app build | Blocked, exit 74 |
| Real UI journeys | Not executed this session |
| Default / AX1 screenshot inspection | Pending |

Compiler commands and final logs are in study-home-docs/internal/evidence/.
The [patch](study-home-docs/internal/evidence/study-home.patch) contains this task's app, test and script changes; generated Xcode membership is already applied in the checkout.

## Real screenshot inventory

**No current simulator screenshots exist for this redesign.** The following are capture targets, not links to claimed images.

| Requested view | Target attachment in native result |
|---|---|
| Study empty | default: study-01-empty-overview, study-01-empty-continue |
| Study populated | default: study-02-populated, created through the real Remember action |
| Fading | default: study-03-fading |
| Blind Spots | default: study-04-blind-spots |
| Reconstruction Labs | default: study-05-labs |
| AX1 Study | AX1 equivalents, with continued viewport captures for tall fields |

Run from local Terminal:

~~~sh
cd /Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast
bash scripts/verify-study-home.sh
~~~

The runner builds, boots the specified simulator, runs the focused journeys at default size and AX1, exports actual attachments and test summaries, then restores the prior text-size setting. Default additionally runs the existing Study navigation and session-start regressions. UI tests use the pre-existing isolated Shelf-UITests store. No new fixture injection or production seed path is introduced.

Output: docs/design/study-home-docs/internal/evidence/native-<timestamp>/default-attachments/ and AX1-attachments/. Attachment filenames are assigned by xcresulttool; its manifest maps the names above to real PNGs.

## Unresolved

1. Execute a fresh native build and the focused UI journeys on the requested simulator.
2. Inspect the six requested real screenshot views, including AX1 wrapping, scroll reachability and colored-surface hit regions; repair any observed defects.
3. Certify the final visual composition only after that inspection.

**Completion gate remains open.**
