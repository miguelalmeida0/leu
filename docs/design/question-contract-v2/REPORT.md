# Question Generation / Admission Contract V2

Implemented and deterministically verified. **The native real-model gate remains OPEN.** No iOS inference success is claimed for this patch.

## Architectural root cause and contract

The old Apple provider authored arbitrary final questions, choices and quotes, while admission required an exact deterministic prompt/answer realization. The actual React page-3 packet offered zero meaningful admissible realizations. The saved candidate also selected a random-key answer with an array-index quote; its rejection was correct.

Old contract: free-form factual generation → exact legacy template admission → zero accepted questions.

New contract: canonical source packet → grounded claims → complete MCQ representability preflight → Apple model selects a permitted claim/operation pair → deterministic realization → independent recompile/equality check plus existing source/quality checks → existing question repository. The dynamic response schema permits only the available paired IDs. The model cannot author the final factual fields. Claim ID, operation, canonical docs/internal/evidence/range and schema/validator versions persist with the question.

Preflight runs before the inference closure. Zero meaningful claims produces `noRepresentableQuestion`; meaningful claims without defensible options produces `noDefensibleChoices` internally and the explicit no-representable-question provider error. Neither calls the model. Question cache identity is versioned to V2; explanation generation/cache behavior is unchanged.

## Actual React packet: before / after

Input is the recovered production analysis, whose canonical page 3 is byte-for-byte equal to `PDFKit.PDFPage.string` from the actual bundled PDF. PDF SHA-256: `7d42381fcbb2e1c6252457bced1a3970015142adbac4a556fb35d7ab4e318640`.

Before: `What do Keys describe?` → `identity`; lengths 21 / 8, below unchanged 30 / 12 admission minima. Zero admissible meaningful templates.

After: **4 meaningful claims, 2 selectable/admissible questions**.

| Claim | Operation | Canonical UTF-16 location / length | Selectable MCQ |
|---|---|---|---|
| stable key | mechanism | 42 / 90 | Yes |
| Reordering | constraint, negated | 133 / 71 | Yes |
| array index | conditional constraint | 263 / 74 | No: existing lexical-cue check |
| freshly generated random key | consequence | 338 / 72 | No: existing lexical-cue check |

Actual accepted deterministic realization:

**Which effect does a stable key help achieve?**

Correct answer, including the original PDF line break:

```text
A stable key helps React match an item to its previous
instance within a list of siblings.
```

The other selectable prompt is **Which restriction applies to Reordering?** Its answer preserves `should\nnot` and the complete restriction. All selectable candidates passed the production validator and their stored ranges produced exactly the same strings through real PDFKit selection. The existing compiler's question bank was included in duplicate checking. JSON round-trip preserved source binding and selected-claim provenance.

This replay is deterministic host evidence, **not model inference**. The admitted-question JSON artifacts explicitly carry `verificationKind: deterministic-host-replay-no-model-inference`.

## Source normalization and admission protections

`CanonicalWhitespaceResolver` collapses only whitespace for lookup and maps normalized UTF-16 units back to the original canonical range. It preserves CRLF, line wraps, tabs, Unicode and original text in stored evidence. A second normalized occurrence, including overlapping occurrences, rejects the mapping. No case, punctuation, number or operator equivalence is introduced.

Example: `items move, are inserted` resolves within the complete attested assertion to `items move,\nare inserted`; the full original assertion at 263 / 74 is retained. This is not fuzzy quote admission. The old free-form candidate still rejects with `fabricatedQuote`.

V2 admission independently rebuilds the menu from the analysis-bound paragraph segments. Claim/operation, prompt, correct option, all options, explanation, quote and concept must exactly equal that realization. Tampering produces `claimMismatch`; changed packet segments produce `wrongSource`. Removing selection proof cannot bypass legacy semantic admission. Qualifiers, negation, code identifiers and numeric bounds remain in the full canonical answer. All original choice count/length, attestation, ambiguity, lexical-cue, prompt quality and duplicate checks remain active. The V2 lexical concept check allows PDF whitespace only after exact claim proof; legacy concept matching remains unchanged.

The compiler is a conservative deterministic grammar recognizer, not a model or general semantic entailment engine. Code blocks, headings, ambiguous mappings, unresolved references and instruction-like sentences cannot supply claims. Supported generic relations include mechanism, consequence, conditional/negative constraints and eligible existing grammatical claim operations. Unknown or insufficient claims may remain unrepresentable.

## MCQ boundary

The current `LearningQuestion` path requires options and a correct option ID. Changing it to open recall would affect the protected session/UI path. V2 therefore uses an explicit **source-assertion selection MCQ**: the correct option is the complete selected assertion; the other two options are complete source-attested assertions with distinct named subjects, comparable lengths and no rejection from the existing lexical-cue check. It never manufactures false technical statements or claims this provides arbitrary misconception distractors. If no defensible pair exists, preflight stops before inference.

## Verification

| Check | Result |
|---|---|
| New targeted core XCTest | 18/18 PASS |
| Unchanged legacy admission XCTest | 6/6 PASS |
| Targeted host XCTest total | **24/24 PASS, 0 failures** |
| Actual React PDFKit replay / every selectable candidate / original source ranges | PASS |
| Generic compiler/realizer contains no React-specific strings | PASS |
| Complete ShelfCore host compile | PASS |
| Apple provider typecheck against installed Foundation Models SDK | PASS (macOS SDK; not full iOS app build) |
| Native test syntax / project membership / structural validation | PASS |
| Native deterministic integration tests | NOT EXECUTED here; 2 added |
| Real iOS model run 1 | BLOCKED before execution |
| Real iOS model run 2 | NOT EXECUTED; same environment blocker |
| Real iOS model run 3 | NOT EXECUTED; same environment blocker |
| Full ShelfTests | NOT EXECUTED; expected new total **89**, conditional on all three model runs passing |

For each unexecuted model run, generated/accepted/rejected/repair/operation/rejection-code metrics are **unavailable**, not zero. The 4 meaningful / 2 selectable counts above come from the actual host packet replay, not iOS inference.

Fresh environment evidence: `simulator-access.log` reports CoreSimulator POSIX 61 (`Connection refused`). The native runner's SwiftPM compiler probe reports `permissionDenied`. The direct targeted `xcodebuild` exits 74 during package resolution because Xcode's temporary package lock is inaccessible. No native test started. These are environment failures, not product test failures.

## Changed code

Added:
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/CanonicalWhitespaceResolver.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/GroundedQuestionContract.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/GroundedQuestionCompiler.swift`
- `Packages/ShelfCore/Tests/ShelfCoreTests/Learning/GroundedQuestionContractTests.swift`
- `ShelfTests/QuestionContractV2IntegrationTests.swift`
- `scripts/test-question-contract-v2-host.py`
- `scripts/verify-question-contract-v2.sh`

Modified:
- `LearningCandidateValidator.swift`: independent V2 claim proof; existing fatal admission checks retained.
- `LearningIntelligence.swift`: source segments, selection and durable versioned provenance.
- `Shelf/Learning/Services/AppleLearningIntelligenceProvider.swift`: constrained real-model selection after preflight.
- `Shelf/Learning/LearningModel+Intelligence.swift`: production preflight before generation work.
- `ShelfTests/LearningRealModelP0Tests.swift`: preflight and per-run production metrics; all original accepted/persistence/planning/PDF assertions retained.
- `scripts/sync-xcode-sources.py` and `Shelf.xcodeproj/project.pbxproj`: membership of the two new native integration tests.

The SHA-256 audit found exactly those seven modified baseline files and **437 unchanged baseline files**. No protected Study, Night Field, Claude/session/recall, reconstruction, navigation, extraction/rendering, voice or explanation-path implementation was changed. Previously supplied session 13/13, Study default 7/7 and AX1 4/4 evidence is preserved; those suites were not rerun or re-certified by this patch. No commit, push or merge.

## Evidence and remaining execution

- `deterministic-tests.log`: real 24-test XCTest output.
- `react-page3-preflight.json`, `react-page3-packet.json`, `react-replay.log`: actual-source claims and admission.
- `react-admitted-mechanism.json`, `react-admitted-constraint.json`: explicitly labelled deterministic accepted objects.
- `change-audit.json`, `before-sha256.json`: protected work audit.
- `native-20260913-130556/`, `native-targeted-attempt.log`, `simulator-access.log`: environment failures.

Run locally from this checkout:

```bash
bash scripts/verify-question-contract-v2.sh
```

The runner enforces targeted core tests, two deterministic iOS integration tests, three separate real-model executions with exported candidates/preflight/metrics, and zero skips. It builds once, reuses the build for all native executions, runs all three attempts even if a model result fails, and runs the full 89 ShelfTests only if all three pass. No Study UI suite is rerun.

Unresolved: fresh native build/integration verification, three successful actual iOS model selections with acceptance/persistence/planning evidence, and the subsequent full 89-test ShelfTests gate. No runtime model or latency result is claimed for V2 until those artifacts exist.
