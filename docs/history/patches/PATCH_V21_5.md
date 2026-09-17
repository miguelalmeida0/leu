# Shelf V21.5 — final Learning OS semantic-control QA repair

V21.5 fixes the last known XCUITest failure in `test33QuestionCommitAndSourceRoundTrip`.

## Root cause

The production question card already exposes stable accessibility identifiers for `commit-answer` and `view-question-source`, but the test still queried those styled SwiftUI controls through `app.buttons[...]`. V21.4 had already introduced `identifiedControl(...)` because XCUI can export a styled SwiftUI control's identifier on the semantic accessibility element rather than the concrete Button query. The answer-option lookup was migrated, but these two lookups were missed.

That left the test harness inconsistent: the real control could be present and accessible while `app.buttons[identifier]` returned no match. The failure therefore occurred before `commitAnswer()` and did not establish a persistence, source identity, or navigation defect.

## Repair

- `test33QuestionCommitAndSourceRoundTrip` now resolves Commit answer and View source through the same semantic-control helper used elsewhere in the V21.4 suite.
- The commit assertion is stronger: after selecting an option, the test now waits for the commit control to be **enabled**, verifying the actual state transition rather than mere existence.
- The native UI contract audit now rejects regressions back to direct concrete-button queries for these styled controls.

No production Learning OS logic, source mapping, persistence, ranking, offline/privacy behavior, or reader navigation was weakened or bypassed.
