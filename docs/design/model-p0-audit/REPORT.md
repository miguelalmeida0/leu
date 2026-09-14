# Real-model P0 — diagnosis, gate not repaired

## Exact failing conditions

ShelfTests/LearningRealModelP0Tests.swift:48 requires accepted > 0. The counter increments only after the production validator accepts a candidate, its source range matches PDFKit selection, and storeModelQuestion succeeds.

Line 52 requires the subsequent real study plan to contain a question whose persisted record has modelProvenance. With zero accepted model questions, that condition also fails. These assertions express the intended gate and were not changed.

## Actual native evidence

Run: docs/design/session-convergence/native-20260913-121148

unit.log:158 records rejected=fabricatedQuote. The only real-model attachment is unit-attachments/FDE50E47-D5B9-4825-9755-467E41335F97.json, exported as real-model-react-page-3.

Observed native counts: generated candidates 1, accepted 0, rejected 1. Repairs 0: this provider/test path contains no repair loop. Actual test duration: 8.838 seconds. The complete native ShelfTests result is 86 passed, 1 failed, 0 skipped, 87 total. The two assertions belong to the same failed test.

The model output:
- prompt: Explain why editing a row can reveal a bad key choice.
- skill: mechanism
- concept: key
- correctChoice: 2 (zero-based)
- selected answer: A freshly generated random key also destroys continuity between renders.
- supportingQuote and explanation: An array index can be a poor key when items move, are inserted or removed.

The model selected the random-key statement while citing the array-index statement. Its prompt copied the page's practice instruction and ended with a period. All four choices replaced PDF line wraps with spaces, so none is attested verbatim under the current contract.

## First rejection: exact source bytes

LearningCandidateValidator.swift:15–17 calls NSString.range(of:) for a literal contiguous quote. The actual PDF contains:

```text
An array index can be a poor key when items move,
are inserted or removed.
```

The model returned a space instead of that newline. The fact is present after whitespace normalization, but the requested literal quote is absent. The code reports fabricatedQuote; that label does not mean the sentence's technical content was invented.

Other independently failed predicates in the SAME saved candidate:
- line 21: the selected answer is absent from supportingQuote (ambiguousAnswer branch);
- line 25: all four choices fail literal source containment (unsupportedChoices branch);
- line 31: the prompt lacks a question mark (weakQuestion branch).

Only fabricatedQuote was emitted by the native short-circuit validator. The other codes above name independently failing predicates, not additional recorded runtime rejection events.

The saved candidate is invalid. It does not justify a validator exception.

## Deeper blocker: zero admissible questions for this packet

Built and executed a host diagnostic against the UNMODIFIED ShelfCore source. This is validator/semantic replay, not model inference and not an iOS test pass.

The recovered UI-test analysis has the identical PDF fingerprint:
7d42381fcbb2e1c6252457bced1a3970015142adbac4a556fb35d7ab4e318640

The diagnostic reads the actual bundled PDF with PDFKit and asserts that page 3's string equals the recovered canonical packet exactly. That assertion passed. The original failed test did not attach its source packet, so same-pdf-source-packet.json is explicitly a recovered and PDFKit-verified reproduction, not a mislabeled original request artifact.

Production validator replay of the original candidate reproduced fabricatedQuote.

LearningCandidateValidator.swift:40–48 also requires the generated prompt AND selected answer to equal QuestionRealizer's output for a quiz-truth claim. This is stricter than merely requesting a mechanism question with source evidence.

The actual semantic compiler produces two page-3 propositions:
1. A code.arrayMap.call.v1 fact with no realizable claim.
2. A heading-derived mechanism claim with prompt "What do Keys describe?" and answer "identity".

The second has a 21-character prompt (minimum 30) and an 8-character answer (minimum 12). It is also the incidental heading question the task explicitly says not to admit simply to increase the counter.

The replay enumerated all quiz-truth propositions in the document whose evidence occurs in the page-3 packet. Feasible exact templates under the unchanged validator: ZERO.

Consequently no prompt/schema-only change and no repeated sampling can produce a candidate that satisfies ALL current predicates for this packet. Even a well-formed, correctly indexed, literal-quote mechanism question would reach semanticReviewRequired unless it matched the unusable heading template.

## Classification

- A: proven candidate-quality/contract failure in the saved model output.
- B: proven pre-existing provider/admission contract mismatch; no evidence that convergence introduced a prompt/schema regression.
- C: the original candidate is not a valid false rejection. Separately, the exact-template admission path has zero feasible outputs for the intended passage.
- D: assertions correctly express the desired model-to-persistence-to-plan gate; changing them to accept zero would hide the defect.
- E: not established by a single native output. The provider uses greedy sampling; three successful native runs have not occurred.
- F: excluded for the inspected path by hashes. Provider, validator, claim extractor, indexer and PDF are byte-identical before convergence, in the failed build's source manifest, and now.

## Changes

No application, validator, provider, extraction, persistence, UI, test or script changes. All 399 audited files remain byte-identical. Only diagnostic files under docs/design/model-p0-audit and a disposable host replay under .build/model-p0-audit were added.

No threshold, source binding, qualifier, negation, duplicate or semantic gate was weakened. No fallback model output was created or installed.

## Requested native verification

RUN 1: actual targeted test-without-building attempt exited 74 before XCTest. CoreSimulator POSIX 61 Connection refused and Xcode temporary package-lock I/O denied. No inference, accepted count, repair count or model rejection code from this attempt.

RUN 2: not executed; same unresolved native execution blocker.

RUN 3: not executed; same unresolved native execution blocker.

Full ShelfTests rerun: not executed because the prerequisite three passes do not exist. Last completed result remains FAIL, 86/87 passed, one failed, zero skipped.

## Protected work

Study Home, Night Field, session/recall presentation and state, reconstruction UI, navigation, PDF extraction, persistence architecture, voice and the working explanation-model path are unchanged by this task.

## Unresolved

1. A generation/admission correction must first make a substantive source-grounded question representable. Prompt wording alone cannot resolve the demonstrated zero-template condition. This diagnosis does not authorize accepting the invalid saved candidate or dropping exact-template validation without a replacement proof of support.
2. Obtain and inspect valid real on-device candidate evidence before changing any validator false-rejection behavior.
3. Execute the single native test three times after a justified repair and report each result independently.
4. Only after three passes, rerun the complete ShelfTests target.

Primary evidence: replay.log, same-pdf-source-packet.json, page3-semantic-propositions.json, targeted-run-1.log, scope.json.
