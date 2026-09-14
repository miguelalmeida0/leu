# Final UI triage — 14 September 2026

Scope: test/support changes only. No production edits, commit, push, reset, reimport, fixture question injection, or quality-gate changes. The complete matrix was established before editing. All twelve original screenshots and accessibility trees, the exact assertions, the preceding forty log lines per failure, helpers, and the corresponding current production implementations were inspected.

Baseline: `native-20260914-100732/ui-full-summary.json`: 62 passed, 12 failed, zero skipped on iPhone Air / iOS 26.5 / A248FB9E-B969-4CF6-A0ED-B2013A3C60A6, content size large.

| Failed test | Original assertion / log line | Classification | Exact cause |
|---|---|---|---|
| ShelfRecoveryV25UITests/test57ConfidenceControlsHaveEqualGeometryAndCompleteLabels | ShelfUITestCase:190 / 7160 | D — readiness | #1: waits for the unrealized duration button before scrolling. |
| ShelfRecoveryV25UITests/test58TrailContinueReturnsToTheRetainedTrail | Recovery:39 / 7361 | C — locator | #2: two legitimate React Notes buttons in separate sections. |
| ShelfSessionExperienceUITests/testMCQPredictionCommitFeedbackAndSourceRoundTrip | SessionExperience:73 / 12563 | B — stale expectation | #3: waits for a question while the actual plan is on recall, 1 of 4. |
| ShelfSourceRecoveryP0UITests/test59ExistingReactPagesOneToThreeRetainTextAndCode | SourceRecovery:13 / 14715 | E — setup | #4: book lookup while restored Study is selected, recall 2 of 12. |
| ShelfSourceRecoveryP0UITests/test60ExistingLibraryActiveRecallRevealsAndReturns | SourceRecovery:13 / 14863 | E — setup | #4: identical retained session; Library was never selected. |
| ShelfSourceRecoveryP0UITests/test61ExistingReactQuestionChoicesExplanationSourceReturn | SourceRecovery:13 / 15014 | E — setup | #4: identical retained session; Library was never selected. |
| ShelfSourceRecoveryP0UITests/test62UninterruptedExistingLibraryReadLensStudySourceReturn | SourceRecovery:13 / 15165 | E — setup | #4: identical retained session; Library was never selected. |
| ShelfWorldClassUITests/test50SemanticQuestionUsesFourLevelCertainty | ShelfUITestCase:190 / 21147 | D — readiness | #1: same unrealized duration button. |
| ShelfWorldClassUITests/test51UnderstandingLensUsesVerifiedSourceFacts | WorldClass:94 / 21362 | B — stale expectation | #5: assumes optional local-fact disclosure always exists. |
| ShelfWorldClassUITests/test52V24PrivacyAndNeuralVoiceControlsAreExposed | V24InteractionSupport:19 / 21692 | C — locator | #6: counts the inline picker's distinct On and Reduced options as duplicate controls. |
| ShelfWorldClassUITests/test53ActiveStudyContextSurvivesInterruption | ShelfUITestCase:190 / 22137 | D — readiness | #1: same unrealized duration button. |
| ShelfWorldClassUITests/test54IrritatedCheckInOffersOptionalRelease | ShelfUITestCase:190 / 22529 | D — readiness | #1: same unrealized duration button, requesting 5 minutes. |

1. **Duration realization:** all four AX trees put TIME at y=839 and Start at y=939.3, while unobscured content ends before the bottom chrome at y=812. The `LazyVGrid` in `LearnTodayScreen.timePicker` still labels the controls “5 minutes” and “10 minutes”. The helper fails before reaching its existing scroll-aware tap. Repair: reveal the button first, retaining existence, hittability, uniqueness, geometry and enabled checks. This is not evidence that the content cannot be scrolled above navigation.
2. **Trail query:** `TrailAddSheet` deliberately offers a whole-document action under Documents and an inline PDF choice under Page range. Both are labeled React Notes, at y=182.3 and y=656.3. Neither has a distinct identifier. Repair: locate exactly one matching button between the measured Documents and Page range headers. Do not take an arbitrary first match. Add confirmation and retained Trail return assertions remain.
3. **MCQ assumption:** the failed screen visibly presents an active recall prompt and answer editor. `ShelfStudySessionPlanner` ranks available questions and recalls and interleaves kinds; it does not guarantee an MCQ at position one. Tests now open the existing React p.3 Lens through production UI to request source-specific generation, require its persisted model explanation and a positive persisted-model-question count, plan the real session, and advance through preceding activities to the admitted model p.3 question. Missing admitted output or a plan without that MCQ remains a failure. No model/mock/cache injection. The other MCQ tests' downstream assumption is repaired through the same support. Test50 now checks confidence is absent before a choice, then verifies all four predictions after choosing. Commit, source quote, return context, geometry and persistence checks remain.
4. **Existing-library setup:** all four AX trees show Study Selected and the same saved recall at 2 of 12. `RootView.restoreStudyOnLaunchIfNeeded` intentionally restores an unfinished session directly. Setup now waits for the foreground root and initial content, selects the existing Library tab and still requires the actual React book. It does not delete or reimport anything. Recall/model journeys explicitly return to the Study landing before using its controls, as their original bodies already intended to end an existing session.
5. **Lens projection:** `UnderstandingLensSheet.localFacts` creates “How it works” only for nonempty local facts; its `relatedFacts` separately exposes Related. The captured current projection has “What this says”, the source-supported committing sentence, Key idea and Related. The repaired test verifies the displayed sentence against the actual origin text, opens Related, requires a verified fact row, and retains its exact target-page/source return and original-passage restoration assertions. It does not force missing local relationships or admit degraded content.
6. **Inline settings picker:** `SettingsScreen` explicitly uses `.pickerStyle(.inline)`. On, Reduced and Off inherit `settings-check-ins`; the saved tree realizes On (Selected) and Reduced. Repair: identifier plus exact option label, scroll into the unobscured Form viewport, require one match for that option, select Off and verify Selected persists after reopening. Other realized siblings must be unselected. Voice/privacy assertions remain unchanged.

Production bugs proven: **none among these twelve failures**. The test repairs still need native execution to establish that the remaining journey assertions pass.

Files changed:

- `ShelfUITests/ShelfUITestCase.swift` — scroll before the duration assertion.
- `ShelfUITests/V24InteractionSupport.swift` — retained-library navigation, actual admitted-question precondition, mixed-plan traversal, inline picker option lookup, reachable completion actions.
- `ShelfUITests/ShelfRecoveryV25UITests.swift` — confidence precondition and section-scoped Trail action.
- `ShelfUITests/ShelfSessionExperienceUITests.swift` — only the failed MCQ test uses the admitted-question precondition/traversal.
- `ShelfUITests/ShelfSourceRecoveryP0UITests.swift` — retained-library setup, current recall identifiers, shared admitted-question journey preparation. Original intact-text, model-page-3, choices, explanation and return assertions remain.
- `ShelfUITests/ShelfWorldClassUITests.swift` — confidence timing, conditional Lens projection, inline preference, interruption precondition.
- `scripts/verify-ui-triage.py` — incremental UI build, six representatives, then a single invocation of exactly the failed twelve only if all representatives pass. Exact counts, zero skips, attachments and protected source hashes required. No automatic retries.
- This report.

Verification:

- Final complete ShelfUITests Swift module compiled against iOS Simulator SDK 26.5: **PASS**, exit 0, empty compiler diagnostics. This is a module compile, not native runtime certification.
- Runner Python syntax: **PASS**.
- 349 app/core-production/native-unit/project input hashes match the original run: **PASS**, no protected changes. Six changed UI-test/support files match the listed scope.
- Representatives (57, 58, MCQ, 59, 51, 52): **BLOCKED, 0/6 executed**. The requested native attempt stopped in the incremental UI build: CoreSimulator POSIX 61 connection refused, plus Xcode's temporary SwiftPM package-lock I/O permission error. No representative test result exists.
- Failed twelve: **NOT RUN, 0/12 executed**. The representative gate has not passed; no fabricated 12/12 result.
- The original 62 green UI tests and all existing certification results are preserved. No completed test gate was rerun.
- Another 74-test run: **NO**, provided the targeted twelve pass. No production implementation changed. Closure remains pending the six representatives and twelve-test result.

Evidence from this attempt is under `native-20260914-100732/ui-triage-20260914-122816-659746/`:

- `build-ui.log` and `build-ui-exit.txt` — actual native build block.
- `typecheck.log` — empty successful final compiler output.
- `scope-check.json` — 349 protected inputs unchanged; six changed UI-test files.
- `original-failure-contexts.txt` — all twelve original assertions with their preceding forty numbered log lines.
- `selection.json` — explicit six-representative and twelve-test selections.
- `ui-source-sha256.json` — inputs at the blocked attempt; final local compile occurred after two small support edits. It is not a runtime pass receipt. Each future native invocation writes fresh hashes and rechecks them before accepting results.

Run from the canonical checkout when native execution is available:

```sh
python3 scripts/verify-ui-triage.py docs/design/bugfix-20260914/native-20260914-100732
```

This single command stops on a failed representative, otherwise proceeds directly to the twelve-test invocation. It never invokes the other 62 tests, the full 74, or already-green core/ShelfTests/session/contrast/default/AX1 gates.
