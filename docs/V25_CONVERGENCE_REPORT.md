# V25 convergence: repairs awaiting executable verification

2026-09-12. The supplied local QA log establishes BUILD SUCCEEDED, 235 core tests with six assertion failures, and a missing UI helper preventing native test compilation. It was preserved at `recovery-docs/internal/evidence/v25-convergence/supplied-qa-v25-recovery.log` before the requested runner was repeated. That successful build predates this patch.

## Concrete repairs

1. **Tradeoff extraction:** the existing pattern recognized the index sentence but rejected its five-character benefit, `reads`, through the general six-character object filter. New TradeoffExtractor validates the complete two-sided statement and stores SemanticTradeoff with explicit benefit/cost subjects, predicates and objects. It supports the nine requested grammatical forms without index/TypeScript facts. SemanticRelation.tradeoff is first-class; the existing pedagogical intent/operator remains application for compatibility with the unchanged V25 bank assertions.
2. **Prevention scope:** `through a typed reference` is retained within the constrained object and recorded as scope, rather than being treated as a means of prevention. The expected question is `What does a readonly property prevent through a typed reference?`, with answer `reassignment`. Abstract means such as `through parameterization` retain mechanism intent. This is a conservative grammatical heuristic, not a general language parser.
3. **Question-bank failure:** the supplied failure is line 37, the assertion requiring an application question. Rejecting the index claim leaves too few same-family tradeoff alternatives. The two-sided extraction restores the candidate family. Application answers use parallel action phrases rather than naming only the correct subject. Debugging options similarly express behavior without the subject name. Additional gates reject extreme option-length differences and unique lexical echoes. These heuristics do not prove arbitrary-source distractor truth.
4. **Lens:** deterministic meaning is composed from both stored sides, with the original passage/proposition provenance. No explanation of B-tree internals or other external mechanism is inserted. The original ten-passage differentiation assertions remain.
5. **Paging:** initial arbitration uses both displacement direction/lead and velocity direction. Slow short diagonals remain vertical; horizontal velocity can establish intent with modest travel; committed axes stay locked. Release requires either a deliberate drag or sufficient horizontally dominant velocity and actual travel. Reversal, boundaries and edge resistance remain. ReaderPageTurnDriver passes actual displacement plus both velocity components instead of substituting velocity as displacement.
6. **UI helper:** openStudyAndStart and its enabled-state wait moved from private ShelfWorldClassUITests methods into shared ShelfUITestCase support. Both suites use the same journey; no test was deleted or replaced with a duplicate journey.
7. **Capture warning:** LearningModel's nested pending-book closure now explicitly uses `self.snapshot`. The supplied log contains one distinct material source warning at this location, repeated across compilation. It also contains the non-material AppIntents metadata notice. The current compiler warning count is unverified.

Semantic cache version is now 4 and question fingerprints use v4, so previously indexed books do not silently retain the rejected/malformed bank. New tradeoff/scope fields are optional for decoding older claims. No semantic-engine feature phase, OCR/embedding dependency, UI redesign or voice tuning was started.

## Retained and additional tests

No existing test method or assertion was removed. Eight methods were added: four general extraction/option-quality methods, one Lens tradeoff composition method and three gesture-arbitration methods. The existing application/debugging assertions and all original PageTurnPolicyTests remain.

- Portable core: 243 methods.
- Apple/PDF: 26 methods.
- UI: 59 methods.
- V25 coverage added since the supplied stale archive: 39 methods (31 existing V25 plus 8 convergence additions).
- New application/debugging bank test prints accepted prompts/options/answers during an actual Swift run; none of those outputs has been observed here yet.

## Executed verification

| Run | Result |
| --- | --- |
| Targeted GeneralExtractionV25Tests / LensDifferentiationV25Tests / PageTurnPolicyTests | Exit 1, `permissionDenied`, zero tests executed |
| Targeted ShelfRecoveryV25UITests | Exit 1, CoreSimulator unavailable, zero tests executed |
| Source/static gates | 16 passed |
| Python tooling regression methods | 102 passed / 3 failed; all three invoke permission-blocked Swift harnesses |
| Changed-Swift syntax parser | 16 changed/new Swift files parsed with no findings; not type-checking |
| Requested `SHELF_QA_LOG=qa-v25-recovery.log ./scripts/qa-and-copy.sh` | Exit 1; blocked Swift harness. Coverage check does not mark omitted tests passed. |
| Independent current app build | Exit 74; package resolution `permissionDenied`, before source compilation |
| All independent runtime batches | All six attempted; all exit 1 before tests |

No successful current build, current Swift assertion result, UI execution or zero-warning compile is claimed. The full runner was attempted once for an explicit current exit status; remaining independent stages were collected separately despite the front gate failure. A prior successful local build is not promoted to proof of the modified source.

Evidence is under `recovery-docs/internal/evidence/v25-convergence/`: targeted logs, current static results, independent build/suite logs, source hashes and `convergence.patch`. The unified patch is against the previous reconstructed ZIP, not an invented Git commit. Current QA output remains at `qa-v25-recovery.log` and `docs/internal/qa/qa-v25-recovery-summary.txt`.

## Required next executable sequence

In a local environment with working Swift/Xcode permissions:

```sh
cd /Users/malmeida/Documents/ChatGPT/Leu/LeuNativeV24_5
./scripts/test-core.sh --filter 'GeneralExtractionV25Tests|LensDifferentiationV25Tests|PageTurnPolicyTests'
./scripts/test-ios.sh -only-testing:ShelfUITests/ShelfRecoveryV25UITests
```

Only after those pass, run:

```sh
SHELF_QA_LOG=qa-v25-recovery.log ./scripts/qa-and-copy.sh
```

Any newly observed failure must be repaired and rechecked; the project remains in convergence until that complete runner exits 0. Physical thumb/swipe/zoom and background-audio behavior still require an iPhone; perceptual voice quality still requires human listening. Those requirements are separate from the current automated execution block.
