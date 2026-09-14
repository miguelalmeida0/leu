**Scope: the two failing core test cases only. Production code is unchanged. No commit/push.**

**Root cause 1 — an unversioned fixture, not deletion of current V5 data.**

`SemanticCoreV24Tests.makeAnalysis` constructed `DocumentAnalysis` without setting its optional `extractionVersion`. Its value was therefore `nil`. `DerivedExtractionMigration` intentionally classifies `(extractionVersion ?? 0) < 5` as outdated and removes its semantic index and questions on repository open. `semanticVersion: 4` and `|v4` question fingerprints in the failure output are separate semantic compiler versions; they do not establish an extraction version of 4.

The fixture now declares `SourceExtractionVersion.current`. The existing persistence test still requires equality with the compiled semantic index and all six question fingerprints, and explicitly requires six generated/reloaded questions. The same test then stores populated V4 and nil-version banks and verifies invalidation both from repository open and from disk, with durable learner attempts unchanged. No assertion was changed to accept an empty current bank.

**Root cause 2 — existing whole-second ISO-8601 persistence precision.**

`FileLearningSnapshotStore` already configures both encoder and decoder with `.iso8601` (`LearningSnapshotPersistence.swift:19–20`). The failing test compared post-persistence records with their original in-memory `Date()` values. The loss occurs at initial serialization, before migration.

The old failing log prints timestamps only to whole seconds. Its original fractional values cannot be recovered from that text. A controlled reproduction with the same Foundation encoder/decoder configuration prints every field using `HistoryFieldDiff`, including 17 decimal places for `timeIntervalSinceReferenceDate`. It performs no migration:

| Field | Before | After | Delta (seconds) |
|---|---|---|---|
| LearningObject.createdAt | 810000000.12500000000000000 | 810000000.00000000000000000 | -0.125 |
| LearningAttempt.occurredAt | 810000000.37500000000000000 | 810000000.00000000000000000 | -0.375 |
| ConfidenceRecord.occurredAt | 810000000.87500000000000000 | 810000000.00000000000000000 | -0.875 |

All other fields are SAME: IDs, document/question/object IDs, source text/range/bounds/section, origin, stale state, type/title/prompt/topics/importance, rating, confidence, correctness, response time, hint count and proposition ID. Full output: `core-repair-field-diffs.log`. These are controlled reproduction values, not invented fractional values for the earlier failed run.

The repaired test first checks the initial file round trip against the supported whole-second contract, preserving exact equality for every other field. It then compares the entire migrated records with the durable pre-migration records using unchanged `XCTAssertEqual`. It also checks exact review-state preservation. The in-memory test continues to require full Date precision. Diagnostic pairs are printed for both serialization and migration during the actual file test. No production format or global equality semantics were changed.

**Changed files.**

- `Packages/ShelfCore/Tests/ShelfCoreTests/Learning/SemanticCoreV24Tests.swift`: current fixture version; current/old/legacy bank coverage in the existing test.
- `Packages/ShelfCore/Tests/ShelfCoreTests/Learning/SourceIntegrityMigrationTests.swift`: explicit durable precision contract, exact pre/post-migration equality and field diagnostics.
- `scripts/verify-bugfix-integration.sh`: safe resume for these package-test-only edits and the two verification scripts; verify all other build inputs remain identical; require current core-test proof; reuse the existing passing contrast result.
- `scripts/verify-bugfix-core-repair.sh`: run the two targeted tests, require 2/2, run full core and require 286/286, then resume existing native evidence. Original failed logs are retained.

**Verification.**

- Changed Swift test files compile against the unchanged actual ShelfCore module: PASS (`core-repair-test-build.log`).
- Field-level ISO-8601 reproduction: PASS (`core-repair-field-diffs.log`).
- Requested two actual XCTest cases: execution attempt has two filesystem permission errors before reaching assertions; NOT 2/2 PASS (`core-repair-targeted-attempt.log`). SwiftPM itself also cannot launch its manifest sandbox here (`core-repair-baseline-attempt.log`).
- Full ShelfCore: NOT RERUN because the targeted gate cannot complete in this session. Current count remains 286. The supplied full run has five assertion failures in two test cases.
- Native certification: NOT resumed before the required core gates pass.
- Both verification scripts pass `bash -n`. The resume hash audit passes: all 365 recorded app/core-production/native-test/project entries are unchanged. Only the four files listed above differ from the existing run's snapshot. The existing build and 55/55 contrast evidence are eligible for reuse.

**Next commands, from `/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast`.**

Run the ordered gates and automatically resume only after both are green:

```bash
bash scripts/verify-bugfix-core-repair.sh docs/design/bugfix-20260914/native-20260914-100732
```

The exact native resume command used after 2/2 and 286/286:

```bash
bash scripts/verify-bugfix-integration.sh --resume docs/design/bugfix-20260914/native-20260914-100732
```

No UI, Study Home, session UX, MCQ quality gate, degraded-page exclusion, extraction V5, or production persistence implementation changed.
