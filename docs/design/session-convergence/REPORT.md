# Leu session convergence — implemented, native certification pending

## Merge

Applied the seven-file SESSION_EXPERIENCE.patch against the current canonical checkout, after a clean dry-run. No ZIP workspace replacement and no Claude project file import.

Integrated:
- Shelf/Learning/QuestionCardView.swift: task/source hierarchy, multiline options, confidence as a prediction, textual answer outcomes, extracted feedback.
- Shelf/Learning/RecallCardView.swift: typed open recall, I don't know yet, honest source comparison, View in PDF, explicit self-rating.
- Shelf/Learning/LabScreen.swift: immediate per-position green checks, neutral unresolved positions, accessible mini-lab up/down controls, scenario withheld until fully solved.
- Shelf/Learning/SessionCompleteView.swift: Claude's final activity summary, self-reported recall labels, practised/revisit sections, Review what you marked / Continue reading / Back to Study.
- Shelf/Learning/QuestionFeedbackView.swift: Your answer / From your source / Why this is the answer; no fabricated open-answer assessment.
- ShelfTests/SessionExperienceTests.swift: Claude's seven tests.
- scripts/verify-session-experience.sh: integrated and adapted to the specified simulator and all requested native gates.

QuestionFeedbackView, SessionCompleteView, and SessionExperienceTests remain byte-identical to the final Claude ZIP payload. See claude-payload-preserved.json.

## Recall state

LearningModel.swift:28 adds exactly recallDraft and recallMarkedUnknown as transient observable properties.

RecallCardView.swift:62 binds the TextEditor to $model.recallDraft. All unknown-selection and comparison content reads/writes the same model fields. Only the reveal/focus state remains local to the view.

LearningModel+Sessions.swift:196 resets both properties in resetActivityState, which already runs on begin/advance/restore. Lines 144–145 clear both on endSession. openSource and its return path do not reset them.

No fields were added to ResumeStudyContext, LearningSnapshot, LearningAttempt, history, or persistence. Typing and selecting I don't know yet do not call persistence or review. Only explicit self-rating calls the existing rateCurrent path.

Six RecallSessionStateTests cover:
1. Exact document/page/excerpt route, return, and card reconstruction retaining a multiline draft.
2. Unknown selection surviving source/card reconstruction without assessment.
3. Advance to another object clearing both fields without a view callback.
4. End/new-session clearing both fields.
5. A real repository checkpoint excluding draft/unknown and creating no attempt, confidence record, or review state.
6. Only explicit rating creating an attempt; open-recall correctness remains nil.

These tests are authored and registered, not yet executed on iOS.

## Integration adjustments

- QuestionCardView.swift:58 shows confidence only after selecting an answer, before commit; line 142 exposes the textual committed outcome to accessibility.
- LabScreen.swift:88 increases mini-lab up/down controls from 28 to 44 points high; native children remain separately accessible. Line 157 resets the shuffled elements when the supplied lab ID changes, matching SessionLabActivity's topic-lab selection on appearance.
- Existing confidence geometry and interruption tests now choose first, preserving their measurement, selection, and restoration assertions. The emotional-journey helper also selects before predicting confidence.
- sync-xcode-sources.py explicitly registers the new test files; the existing script's fixed lists otherwise omitted them despite including them in the inventory. Project membership was regenerated locally and validated. See membership.json.

## Build and verification

| Gate | Current evidence |
|---|---|
| validate.py | PASS; 561 project objects and all source memberships resolve |
| check-night-field.py | PASS |
| contrast suite | 55/55 PASS |
| Study input and UI contracts | PASS |
| All UI-test sources typechecked against installed iOS SDK | PASS, exit 0 |
| Native build | BLOCKED; xcodebuild exit 74, CoreSimulator connection refused and temporary package-lock I/O denied |
| Full app direct typecheck | BLOCKED; Observation macro plugin cannot execute in this session |
| ShelfCore tests | BLOCKED before execution; SwiftPM target-info permissionDenied |
| Current Shelf unit tests | 0 executed in this session |
| SessionExperienceTests | 7 registered, 0 executed |
| RecallSessionStateTests | 6 registered, 0 executed |
| Study Home DEFAULT after integration | NOT RUN; prior 7/7 certificate preserved |
| Study Home AX1 after integration | NOT RUN; prior 4/4 and repaired single 1/1 certificates verified and preserved |
| Open recall / source return / MCQ / reconstruction / completion | Native tests implemented; NOT RUN after integration |
| Visual hard gates | NOT CERTIFIED after integration |

## Native runner

Run from LeuNightFieldContrast:

```sh
bash scripts/verify-session-experience.sh
```

Uses A248FB9E-B969-4CF6-A0ED-B2013A3C60A6. Does not create, erase, or reseed the simulator. Existing Study regressions retain their established isolated Shelf-UITests fixtures; new session tests use --uitesting without --reset-library. Production Shelf library files are not selected by these tests.

Build-for-testing runs once, followed by test-without-building for:
1. SessionExperienceTests + RecallSessionStateTests: 13 expected.
2. Entire current ShelfTests target: exact actual count exported, no skips allowed.
3. Study DEFAULT: 7 expected.
4. Study AX1: 4 expected.
5. Existing confidence geometry and interruption restoration: 2 expected.
6. Five real session/source journeys at default size.
7. Same five journeys at AX1.

Every stage exports xcresult, summary, test tree and attachments, and stops on a failure or skip. Original content size is restored on exit. Source hashes identify the exact integrated build inputs. The original Study certification bundles are never overwritten.

## Screenshots

No post-integration simulator screenshot exists yet. Do not relabel pre-integration Study images as session certification.

The session tests capture typed source comparison/return, unknown selection/return/reset, MCQ confidence/feedback/source/return, partially correct reconstruction/check removal/full solve, and actual completion/return. Exact exported PNG paths will come from sessions-default-attachments/manifest.json and sessions-AX1-attachments/manifest.json under the fresh native run.

Current failed native startup evidence:
- native-20260913-120345/simulator.log
- build.log
- native-attempt.log

## Protected systems

Hash audit confirms LearnTodayScreen, memory sections, LearnSecondaryModes, RootView, PrimaryTabBar, all design tokens, ShelfCore, learning providers/intelligence, PDF extraction, durable persistence/checkpoint implementation, explanation/model generation, and voice are unchanged.

Only the explicitly requested transient recall properties and their session reset lifecycle were changed in LearningModel and LearningModel+Sessions. See scope.json and before-sha256.json.

## Unresolved

1. Execute the local native runner; the actual attempt here failed before XCTest.
2. Repair any native compilation or journey failures shown by that run, without weakening assertions.
3. Inspect default and AX1 session screenshots for every visual hard gate.
4. Report the actual unit, journey, and regression counts and exact repaired screenshot paths.

No commit or push. The integration is present in code; the final convergence gate remains OPEN until native and visual results are green.
