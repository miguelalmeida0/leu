# Leu V34 — Capability Plan

Branch: `claude/leu-v34-capability-upgrade` (local only, no push).
Scope: make Leu's learning system materially more capable **without** changing its design,
navigation, visual language or product identity, at zero cost, with no new dependencies.

This plan was written after a full audit and **before** major implementation. Every
number in the baseline was measured on this branch's starting commit (`bf7c5cb`).

---

## BASELINE

```
BASELINE
--------
Tests:        320 XCTest cases in ShelfCore (Linux, Swift 6.1.3, official toolchain
              from the swift:6.1-noble image; layer digest verified).
              The unmodified test target does NOT compile on Linux: one test imports
              CryptoKit unconditionally and one calls XCTestCase() (macOS-only init).
              With those two portability edits applied in a scratch copy only:
              320 executed, 0 failures.
Failures:     0 (after the two portability edits); build failure without them.
Skipped:      0
Known warnings: 0 compiler warnings on a clean build (19 s clean build).
Performance:  Full core suite 24.6 s. Slowest test 12.8 s.
              Real 345-page study manual (docs/v28/fixtures/...mobile_mastery.pdf):
                DocumentAnalyzer        0.8 s
                QuestionV3Contract      1.6 s (all pages)
                SemanticCompiler + SemanticQuestionCompiler   91.5 s  <-- indexing stall
Learning-quality evaluation (new labeled fixture, 92 learner explanations,
written before any V34 code; 49 dev / 43 held-out):
              Current Teach Leu validator (V27):
                dev:      actionable diagnosis 5/49 (10%), claim alignment 2/45 (4%),
                          issue recall 4/28, 38 false issue flags, 23/49 cases with
                          zero comparable claims (Teach Leu cannot run)
                held-out: actionable 6/43 (14%), claim alignment 0/41 (0%),
                          issue recall 6/22, 33 false issue flags, 39/43 cases with
                          zero comparable claims
              Question yield on 7 real documents (app-like block reconstruction):
                V3 source questions (production "admitted" path): 2 total
                (React Notes only); 0 on the 345-page manual (38 claims found).
                Legacy semantic MCQ bank on the manual: 444 questions, including
                malformed stems ("What does an HTTP request?", "What does an array
                method that return?"), duplicate prompts with different answers
                ("What is meant by HTTP?" x2) and instruction-derived items
                ("Which concept is described as authoritative, ...?" -> "Decide what").
Generation latency: Apple Foundation Models cannot run on Linux; no model latency
              is claimed. Deterministic paths measured above.
Important existing defects:
  D1  Teach Leu only recognises exact sentences, a literal "not" removal and one
      hardcoded React paraphrase; any other wording is "Your source doesn't settle
      this". It cannot run at all on definition-card pages (the manual's format).
  D2  Recall answers are typed but never evaluated ("Leu does not evaluate the answer").
  D3  A wrong multiple-choice answer (a reversed statement or another concept's
      statement) carries a precise misconception that is discarded.
  D4  No learner model beyond per-object spaced-repetition numbers; no misconception
      memory; confidence is recorded but only used for "blind spots".
  D5  Question choice never changes cognitive operation; no diversity protection
      across sessions; no prerequisite awareness.
  D6  The V3 extractor rejects definitional fragments ("A constraint linking ...")
      and pronoun-led sentences ("It protects ...") that follow a concept heading,
      so concept-card documents produce almost no grounded claims.
  D7  Stale snapshot writes: several async paths assign `snapshot = await
      repository.snapshot()` after suspension; a slower task can overwrite a newer
      in-memory snapshot (e.g. commitAnswer's event task vs the checkpoint task).
  D8  SemanticQuestionCompiler realizes every proposition O(n^2) times (91.5 s).
  D9  Hardcoded special cases posing as intelligence: TeachLeu identity paraphrase
      (React-only regex) and ActivityValidator (two literal sentences).
```

---

## 1. Current architecture

* **App (SwiftUI, iOS 17+)** — `Shelf/`. `AppContainer` composes services. Learning UI:
  Study home, study sessions (`QuestionCardView`, `RecallCardView`, `DiagramRecallStudyView`,
  labs), Reader learning actions, `TeachLeuSheet`, Explain Like I'm 10 sheet. Observable
  models (`LearningModel`, `ReaderIntelligenceModel`, `ExplanationController`) orchestrate.
* **Portable core (`Packages/ShelfCore`, Foundation only)** — domain, persistence and
  intelligence:
  * *Source*: PDFKit extraction (app) → `DocumentAnalyzer` segments → `DocumentAnalysis`
    with canonical page text and a spatial-integrity flag. `CanonicalWhitespaceResolver`
    binds any quote to an exact UTF-16 range.
  * *Claims & questions*: `GeneralClaimExtractor` / `SemanticCompiler` →
    `SemanticQuestionCompiler` (legacy MCQ bank, built at indexing).
    `GroundedQuestionCompiler` → `QuestionV3Contract` (strict source-attested MCQs with
    counterstatement distractors; independently re-admitted on every load).
  * *Model*: Apple on-device Foundation Models may only **select** a claim ID or propose
    learner/source pairs; all factual output is source-derived and validated.
  * *Memory*: `ShelfReviewScheduler` (per-object stability/difficulty), `ShelfStudySessionPlanner`,
    `TopicLearningAggregator`, `ConceptImportanceModel`.
  * *Understanding*: `TeachLeuValidator` (exact / literal polarity / one audited paraphrase),
    `UnderstandingAttempt` + `UnderstandingEvent` persisted and source-rebound.
  * *Persistence*: `LearningRepository` actor, one validated transaction per mutation,
    `FileLearningSnapshotStore` atomic replace + previous checkpoint + quarantine.
* **Knowledge** — passages, BM25, curated `ConceptCatalog` (parent hierarchy), user
  connections/chains. Keyword-level; not used by study.

Strengths to preserve: exact source binding, refusal to present model output as fact,
explicit state machines around generation, atomic persistence, honest evidence culture.

## 2. Current capability gaps

1. **No diagnosis of understanding** (D1, D2): the learner's own words are the richest
   signal Leu collects, and today they produce either an exact-match echo or silence.
2. **No memory of what the learner gets wrong** (D3, D4): misconceptions evaporate.
3. **No adaptation** (D5): the next question ignores what just happened.
4. **Grounding coverage gap** (D6): the strict extractor is safe but blind to the most
   common study-material format (heading + definition + "It ..." sentence).
5. **Question quality debt** (legacy bank malformed stems; zero V3 yield on real books).
6. **Async correctness debt** (D7) and **indexing performance debt** (D8).

## 3. Highest-leverage opportunities

A small set of foundational abstractions unlocks most of the requested capabilities:

| Foundation | Unlocks |
|---|---|
| `LearningClaim` with explicit `ClaimGrounding` (literal vs resolved subject) and exact evidence spans | source grounding, rubrics, probes, concept graph, prerequisites |
| `UnderstandingDiagnoser` (claim-level alignment, issue detection, smallest intervention) | Teach It Back 2.0, recall evaluation, misconception capture, remediation |
| `LearnerModelState` (concept mastery by operation, misconception records with decay, calibration) | mastery, misconception memory, confidence calibration, retrieval priority |
| `LearningProbe` + validator + diversity guard + `AdaptiveProbeSelector` | adaptive questions, diversity, transfer, misconception probes, prerequisite detours |

## 4. Proposed architecture changes

All new intelligence is deterministic, Foundation-only and lives in ShelfCore where it is
fully testable. The app receives thin wiring through existing surfaces.

```
Learning/Intelligence/Claims/      LearningClaim, ConceptKnowledgeCompiler, ConceptGraph
Learning/Intelligence/Diagnosis/   LearnerText (lexicon), ClaimRubric, UnderstandingDiagnoser,
                                   UnderstandingDiagnosis, InterventionPlanner, DistractorAnalysis
Learning/Intelligence/Probes/      LearningProbe, ProbeGenerator, ProbeValidator,
                                   ProbeDiversity, AdaptiveProbeSelector
Learning/Memory/LearnerModel/      LearnerModelState, LearnerModelReducer, RetrievalPriority
Learning/Persistence/              SnapshotRevisionGate (+ repository revision counter)
```

* **Grounding**: literal claims come from the unchanged V2/V3 extractor. New
  heading-bound claims are produced only when a definitional fragment or a leading
  `It`/`They` directly follows a concept heading; the antecedent heading span is stored,
  so every inference is auditable (`grounding = .resolvedSubject(antecedent:)`). Interview
  sections contribute third-person *supporting* claims only (never MCQ answers).
  **V3 contract untouched** — persisted questions keep re-admitting identically.
* **Diagnosis**: lexical-semantic alignment with morphology, a curated paraphrase and
  antonym lexicon, negation scope, quantifier strength, role reversal and concept
  confusion against sibling concepts. Every verdict carries its evidence tier. The V27
  exact validator remains the proof layer; the diagnoser is additive and labelled as
  lexical evidence, never entailment.
* **Learner model**: persisted inside `LearningSnapshot` (new optional field, decoded with
  defaults, bounded collections) and updated in the same repository transaction as the
  attempt it derives from — no second file, no cross-file consistency problem.
* **Adaptive probes**: open recall prompts carry grounded rubrics and are evaluated by the
  diagnoser; concept-recognition MCQs use sibling concept names (true statements) as
  options. The selector climbs define → purpose/mechanism → contrast → example/transfer,
  targets active misconceptions, and detours to a weak prerequisite once, remembering the
  original objective.
* **Planner**: `ShelfStudySessionPlanner` gains learner-model-aware retrieval priority and
  attaches probes to recall activities (new optional `StudyActivity.probe`).
* **Stale state**: `LearningRepository` exposes a monotonic revision; the app applies a
  fetched snapshot only if it is not older than the one on screen.
* **Performance**: memoize per-proposition realization in `SemanticQuestionCompiler`
  (identical output) and add surface gates for the malformed families listed above.

## 5. Feature priorities

P0 (finish first): Teach It Back diagnosis; adaptive probe engine; source grounding;
mastery + misconception model; generation quality gates; stale-request correctness;
learning continuity (persisted learner model and remediation objective).

P1: prerequisite remediation; concept graph relations; retrieval priority; grounded
explanation strategies (contrast, prerequisite, example, step order); question diversity;
transfer (recognise the concept in the source's own example).

P2: confidence calibration refinements; further performance work.

## 6. Risks

| Risk | Mitigation |
|---|---|
| Lexical diagnosis mistaken for understanding | Evidence tiers in every verdict; conservative contradiction rules; held-out evaluation; UI wording states what was compared, never a grade |
| False contradiction on positive paraphrase of a negated claim | Dedicated fixtures (dev-react-02, dev-state-02); antonym-aware polarity |
| Heading resolution attaches a claim to the wrong subject | Only immediate heading → fragment / pronoun adjacency; heading must be a noun phrase; antecedent span stored; adversarial tests |
| Changing V3 claim sets would drop persisted questions | V3 extractor and contract left unchanged |
| App code cannot be compiled on Linux | Keep app changes minimal, mechanical and syntax-checked with `swiftc -parse`; all logic in tested ShelfCore |
| Snapshot growth | Bounded learner-model collections; misconception decay |
| Overfitting the diagnoser to the fixture | Held-out split written before implementation and never used for tuning |

## 7. Testing strategy

* Keep all 320 existing tests green; fix the two Linux portability defects in tests.
* Unit + semantic tests per capability (behaviour, not implementation mirrors).
* Quality evaluation on the real-text corpus (`Tests/Fixtures/leu-real-corpus.json`,
  regenerated by `Tests/Fixtures/tools/build_corpus.py` from PDFs already in the repo)
  and the labeled diagnosis set; both baselines stay executable side by side.
* Scripted learner simulations for adaptation, misconception decay and retrieval priority.
* State-transition tests for stale snapshot admission and persistence migration.
* Adversarial inputs: empty/one-word/huge passages, nonsense and very long answers,
  unexpected correct wording, duplicate concept names, missing graph nodes, legacy
  snapshots without V34 fields, future learner-model versions.
* Performance assertions on the 345-page corpus.

## 8. Success metrics

| Metric | Baseline | Target |
|---|---|---|
| Actionable diagnosis (dev / held-out) | 10% / 14% | >= 60% / >= 45% |
| Claim alignment, lenient (dev / held-out) | 4% / 0% | >= 70% / >= 55% |
| Concept cards with a comparable grounded claim | 38 claims / 345 pages | >= 90% of concept cards |
| Grounded probes per concept card | 0 V3 questions | >= 3 probes, >= 2 operations, for >= 80% of cards |
| Probe grounding validity | n/a | 100% resolve exactly; 0 leakage by gate |
| Semantic compile, 345 pages | 91.5 s | <= 10 s, identical retained output |
| Adaptation simulations | none | all scripted expectations pass |

## 9. Implementation order

1. Test portability fixes; corpus + labeled fixtures (done before this plan).
2. `LearningClaim` / `ConceptKnowledgeCompiler` / `ConceptGraph` + corpus coverage tests.
3. `UnderstandingDiagnoser` + intervention planner + labeled evaluation (dev only).
4. `LearnerModelState` + reducer + distractor analysis + repository integration + migration tests.
5. Probes: generator, validator, diversity guard, adaptive selector + simulations.
6. Planner integration (retrieval priority, probes on activities, prerequisite detour).
7. Semantic compiler memoization + malformed-stem gates.
8. Snapshot revision gate (core + app).
9. App wiring through existing surfaces (Teach Leu, recall comparison, answer feedback).
10. Full validation, held-out evaluation, adversarial review, report, single local commit.
