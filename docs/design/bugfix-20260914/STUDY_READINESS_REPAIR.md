**Scope: UI test/support hardening only. No production code changed. No commit/push.**

The saved DEFAULT run has six passes and one failure at the initial `learn-screen` assertion in test49. Its accessibility tree shows `primary-shelf` (Library) Selected, the root bottom chrome present, and `primary-learn` unselected. The user-provided standalone test49 result is 1/1 PASS. This repair treats the batch failure as navigation readiness flakiness, not a production regression.

`ShelfUITests/StudyInteractionSupport.swift` now provides `openStudyTab()`:

- Before any tap: wait up to eight seconds for the app to be foreground, the root bottom chrome to exist, and the Study button to exist, be enabled and be hittable.
- Tap once; wait up to three seconds for `learn-screen` or Study's Selected trait.
- If neither arrives: re-query the controls and permit one retry only while Library (`primary-shelf`) is still Selected and the same readiness checks pass. Check for a late transition before retrying. There is no retry loop or unconditional second tap.
- After navigation acknowledgement: still require `learn-screen` within eight seconds. A selected but broken Study tab fails.
- On genuine failure: attach a screenshot, foreground accessibility tree and explicit app/chrome/tab selection/hittability/frame state.

Both tests in `ShelfStudyInteractionUITests.swift` use this helper. All secondary-destination, content, enabled/hittable, collapse/removal and Progress assertions remain.

`scripts/verify-bugfix-integration.sh --repair-default` checks the saved green prerequisites, compiles the changed UI runner, then executes only the seven DEFAULT tests. It keeps the original failed DEFAULT result and stores a new timestamped result directory. Only a 7/7, zero-failure, zero-skip result is promoted for resume. Remaining certification phases then continue; saved green core, ShelfTests, session and contrast gates are reused. UI source hashes must match the refreshed runner/result before normal resume accepts the changed test code.

Verification performed here:

- Entire UI test Swift module compiled against the iOS Simulator SDK: PASS. `study-readiness-compile.log` has no compiler diagnostics.
- Runner Bash syntax: PASS.
- All 349 recorded app/core-production/native-unit/project source entries match the existing run's snapshot. RootView, PrimaryTabBar, Study navigation, and production behavior are untouched.
- Requested DEFAULT attempt: BLOCKED before test execution by CoreSimulator POSIX 61, Connection refused. See `study-readiness-default-attempt.log` and the run's `simulator.log`.
- Existing evidence preserved: ShelfCore 286/286, ShelfTests 92/92, session 13/13, targeted bugfix 3/3, contrast 55/55. None was rerun in this repair.
- DEFAULT 7/7 is not yet verified; the standalone 1/1 result is not being added to the previous batch to manufacture a pass.

From `/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast`:

```bash
bash scripts/verify-bugfix-integration.sh --repair-default docs/design/bugfix-20260914/native-20260914-100732
```

After a successful repair run, ordinary `--resume` uses the promoted DEFAULT evidence and refreshed UI runner hashes.
