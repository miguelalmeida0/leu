# Study Home P0 repairs — certification gate OPEN

2026-09-13. Checkout: /Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast.

ClaudeSessionFinal has not been integrated, inspected or modified by this task.

## Secondary Modes diagnosis

The saved default failure is test49, ShelfStudyInteractionUITests.swift line 33: app.buttons["Start interview"].exists was false after the Interview Mode navigation bar appeared. Source still declares that exact label and the existing startInterview handler. The screenshot shows the initial long Subject/Session Form, with explanatory text beginning below the visible bottom edge. The action is after that text; the collection's exported hierarchy does not yet contain that off-screen row.

Classification: off-screen/lazily realized at the initial Form position. It was not renamed, and the floating main navigation is not visible over this modal. The old test did not attempt scrolling, so its failure alone does not prove permanent unreachability. It is not evidence that the handler is missing.

Repair: move the same action into an opaque bottom safe-area inset, outside the lazy rows. It remains available while the learner scrolls choices. Existing existence assertion is retained and supplemented by isHittable. No mock, alternate destination or weakened check.

## Product repairs

- RootView: one physically allocated content region above the measured, dynamically sized bottom chrome. Content has a rectangular hit region and is clipped; the capsule stays in an opaque reserved area. No hardcoded device/nav height.
- Study and Progress: clip scroll drawing to bounds, keeping scrolled text out of the status/safe-area and navigation regions. Progress history gets the same measured viewport probe as Now.
- PrimaryTabBar: at accessibility sizes, stack icon above label, removing the observed Library word split caused by the horizontal icon/label competition.
- Builder: retain its original choices and start handler. Duration choices use two columns at AX sizes; Start text wraps, while the redundant inline duration is omitted at AX sizes. The time/action region is measured together.
- Continue: heading uses existing source section metadata, matching analyzed-section metadata, an explicitly authored object title, then the actual document title. The original source string is a secondary excerpt bounded to 160 characters plus ellipsis and three displayed lines. No persistence or source text is rewritten; original source navigation remains.
- Empty review fields: minimum content height reduced from 240/208 to 126 points, retaining padding, surfaces and readable content. Populated heights and existing review handlers remain.

Six app source files changed. 354 other app/package files are byte-identical. Model/provider/extraction/persistence/voice and reconstruction logic have no changes. See scope.json and study-home-p0.patch.

## Verification

- Six changed views: PASS typecheck against the existing real compiled production Shelf module, using installed iOS SDK. This is not a full app build.
- All UI-test source files: PASS typecheck.
- Contrast: 55/55 PASS.
- Night Field / Study source contracts: PASS.
- Project membership/file limits: PASS.
- Root lifecycle/source contract: PASS.

The newly requested native run was actually attempted:
../study-home-evidence/native-20260913-110849/build.log

It stopped before compilation, exit 74: CoreSimulator connection refused and an I/O permission error for Xcode's temporary workspace-state lock. No new app or UI capture is claimed.

The earlier native-20260913-103833 default result remains 4 PASS / 1 FAIL. Its subsequently completed AX1 result is 0 PASS / 2 FAIL, both in the old capture-positioning loop. These are preserved as BEFORE evidence, not certification of these repairs. The capture helper now uses measured drags to avoid AX overshoot and requires a fully fitting field to be inside the viewport.

## Required current screenshots

No screenshot of this repaired revision is yet available. The tests now produce these ten checkpoints and assert complete controls/last rows are inside the root content region and above the navigation. Frame assertions supplement manual visual inspection; they are not substitutes for it.

| No. | Requested capture | Native attachment | Current status |
|---|---|---|---|
| 01 | Study empty collapsed | default / 01-study-empty-collapsed | Pending |
| 02 | Study populated collapsed | default / 02-study-populated-collapsed | Pending |
| 03 | Builder expanded | default / 03-builder-expanded | Pending |
| 04 | Fading and Blind Spots | default / 04-fading-blind-spots | Pending |
| 05 | Labs last row above nav | default / 05-labs-last-row | Pending |
| 06 | Progress last row above nav | default / 06-progress-last-row | Pending |
| 07 | AX1 top | AX1 / 07-study-top | Pending |
| 08 | AX1 builder subjects | AX1 / 08-builder-subjects | Pending |
| 09 | AX1 time and Start | AX1 / 09-builder-time-and-start | Pending |
| 10 | AX1 Labs last row | AX1 / 10-labs-last-row | Pending |

Run once from local Terminal:

~~~sh
cd /Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast
bash scripts/verify-study-home.sh
~~~

A fresh run is necessary because app/test source changed. Do not resume the pre-repair 103833 bundles. The runner builds once; AX1 reuses that build with test-without-building. Expected targeted totals: default 7 tests, AX1 4 tests, zero skips. Exports land in each new run's default-attachments and AX1-attachments folders.

## Unresolved

1. Fresh native build and secondary-mode journey pass on the requested iPhone Air simulator.
2. All ten current default/AX1 captures inspected: no clipped/covered actions, safe top area, reachable expanded builder and final rows.
3. Only after both are green can the Claude integration gate close. No merge has been performed.
