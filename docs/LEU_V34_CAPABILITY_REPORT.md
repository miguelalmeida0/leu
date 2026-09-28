# Leu V34 — Capability Report

Branch `claude/leu-v34-capability-upgrade`, one local commit on top of `bf7c5cb`
(“docs: upgrade architecture diagrams”). Nothing was pushed. The plan written before
implementation is `docs/LEU_V34_CAPABILITY_PLAN.md`; this report states what was actually
built, how it was measured, and where it falls short.

---

## 1. Executive summary

Leu can now read what a learner writes and say, in the source's own words, what was right,
what is missing and what is wrong. It remembers misconceptions, retests them, and adapts
what it asks next. All of it is deterministic, on-device and free: no model, network or
paid service is involved, and every sentence Leu puts in quotation marks is an exact span
of the learner's PDF.

* **Teach It Back 2.0.** A lexical–semantic diagnoser compares an explanation with the
  grounded claims of the passage or concept card. On the labeled evaluation set (written
  before any V34 code), actionable diagnoses rose from **10% → 92%** on the development
  split. On the held-out split they rose from **14% → 56%** on the first, blind run;
  after general fixes that run exposed, the non-blind re-run reaches **74%**.
* **Grounding.** The old extractor found 38 comparable claims on the real 345-page study
  manual. The new concept compiler finds **887**, and **308 of 315 concept cards (98%)**
  can now be taught back. Every claim cites an exact current span. A subject is inferred
  only from the heading a sentence sits under, and the heading is stored with the claim.
* **Learner model.** Mastery is tracked per concept and per kind of question, with
  forgetting. Misconceptions are remembered in the learner's words, decay in salience,
  and retire only after answers Leu checked, about the same idea, on two distinct days.
  The model also tracks confidence calibration and prerequisite detours with a return to
  the goal. It is persisted inside the existing snapshot and updated in the same
  transaction as each answer.
* **Adaptive questions.** Grounded probes span 10 internal reasoning modes over 4 levels
  (recognise → explain → connect → transfer). **250 of 315 cards (79%)** have at least 3
  probes of at least 2 kinds, and no quoted definition or example gives its answer away.
  Sessions put live misconceptions first, detour once to a weak prerequisite, avoid
  repetition, and turn to explanation when confidence outruns results.
* **Reliability and speed.**
  * Snapshots older than the one on screen can no longer overwrite it.
  * Planning runs off the main actor, is deterministic, reads each book's knowledge
    separately, and a 30-minute session is no longer 3 activities long.
  * Semantic compilation of the manual went from **91.9 s → 9.2 s**, with byte-identical
    output.
  * 99 malformed or ambiguous legacy questions are now filtered out, including from banks
    already stored on a device.
  * Structural validation, which failed at the base commit, passes.
* **Independent review.** A separate adversarial review of the finished diff found 7
  major problems and a set of minor ones (see the appendix). All were fixed before the
  commit except two minor points left deliberately, with reasons. Every major fix has a
  test that fails without it, except the recall reveal, whose view change can only be
  type-checked here. One fix cost evaluation points on purpose: an inference path that
  also invented facts was removed (§6).
* **No redesign.** The app changes reuse existing sections and styles. They add a
  "NEXT STEP" line in Teach Leu, a "Compared with your source" line after recall, and a
  one-line note when a wrong option can be traced to the source.

---

## 2. Baseline vs final

| Measure | Baseline (`bf7c5cb`) | V34 |
|---|---|---|
| ShelfCore tests (Linux, Swift 6.1.3) | 320 (after 2 test-portability edits), 0 failures | **423**, 0 failures |
| Compiler warnings (clean build) | 0 | 0 |
| Diagnosis — dev, actionable | 5/49 (10%) | **45/49 (92%)** |
| Diagnosis — held-out, actionable | 6/43 (14%) | **24/43 (56%) blind first run**; 32/43 (74%) after fixes (non-blind) |
| Claim alignment (lenient) dev / held-out | 2/45 (4%) / 0/41 (0%) | 41/45 (91%) / 37/41 (90%) |
| Issue recall dev / held-out | 4/28 / 6/22 | 27/28 / 17/22 |
| False issue flags dev / held-out | 38 / 33 | 2 / 3 |
| Comparable grounded claims, 345-page manual | 38 claims | 887 claims; 308/315 cards comparable, 302 with a definition |
| Cards with ≥3 probes of ≥2 kinds | 0 | 250/315 (79%), none leaking its answer |
| V3 source questions on the manual | 0 | 0 (V3 contract intentionally untouched) |
| Legacy semantic MCQ bank on the manual | 444 incl. malformed/ambiguous | 345, every retained item byte-identical to before |
| Semantic compile, manual (debug) | 91.9 s (index 5.1 + questions 86.9) | **9.2 s** (index 5.0 + questions 4.2) |
| Knowledge compile, manual (debug) | n/a | 2.3 s (deterministic) |
| 30-minute planned session on the manual | 3 activities, planned on the main actor | 25 activities, 22 carrying a grounded question, planned off the main actor |
| `scripts/validate.py` | **fails** (god-file + stale manifest) | passes |
| Learner model / misconception memory / calibration | none | persisted, bounded, tested |

---

## 3. Capabilities

Status: **delivered** (built, wired and tested), **partial** (built and tested, limited
reach), **limited** (honest constraint noted).

| # | Capability | Status | What exists |
|---|---|---|---|
| 1 | Source-grounded learning engine | delivered | `LearningClaim` with `ClaimGrounding`: literal, or resolved from the heading it sits under (a definitional fragment, or a leading "It"/"They" right after the heading's own subject), with the heading span stored. `ConceptKnowledgeCompiler` reads source roles: *In one breath* gives core claims, *Say this* gives supporting claims, and memory hooks and advice give none. Examples are kept, code included. Acronym expansions become aliases. Relative clauses without "that" ("A message a client sends …") are read as fragments, not sentences. Anything ambiguous is refused, including a pronoun that could refer to more than one thing. Feedback cites only the source's words inside quotation marks (`LearningClaim.citation`). |
| 2 | Teach It Back 2.0 | delivered | `UnderstandingDiagnoser` gives per-claim coverage (covered / partial / contradicted / missing) and per-statement verdicts. Issues: contradiction, causal reversal, overgeneralisation, confusion with a named concept, unsupported, circular, verbatim, missing idea, dropped condition, nonsense. A keyword list earns nothing. Every verdict carries its evidence tier (`exact` or `lexical`; never "entailment"). `TeachBack.assess` renders into the existing Teach Leu sections: only fully covered ideas under *You captured*, partly covered ones under *Worth adding*, and a NEXT STEP. Stored results are re-admitted only for their own explanation and while their sources are current. |
| 3 | Adaptive question engine / internal reasoning modes | delivered | `ProbeOperation` (define, recognizeDefinition, purpose, mechanism, condition, contrast, misconceptionCheck, recognizeExample, applyExample, sourceQuestion). Supporting pieces: `ProbeGenerator`, `ProbeValidator` and `AdaptiveProbeSelector`. The learner never sees the taxonomy. |
| 4 | Mastery model | delivered | `OperationMastery`: a Beta estimate over evidence decayed with a 45-day half-life, times retention whose stability doubles with each success on a distinct day. Concept level 0–4; failing basics cap the level; self-ratings weigh half. One answer is one observation: a typed recall compared with the source replaces the self-rating rather than adding to it. |
| 5 | Misconception memory with decay | delivered | `MisconceptionRecord` holds the learner's own wording, occurrences and status (active → resolving → resolved). Salience decays with a 21-day half-life but never retires by time alone. A record retires only after correct answers Leu checked (a scored choice or a compared explanation, never a self-rating) about the same claim, on two distinct days. A confusion retires only when the learner tells the same two concepts apart. A relapse reopens the same record. |
| 6 | Concept graph 2.0 | delivered | `uses` and `contrastsWith` edges, each with an evidence span. Mentions match whole, most-specific names ("HttpOnly cookie" is not also "cookie"; "HTTPS" is not "HTTP"). A contrast needs a same-sentence juxtaposition, a contrast marker, or parallel verbs. Contrast edges fell from 31 (≈8 real) to 10 (7–8 real). Output is deterministic; the first version depended on hash order. Lookups are made within one document (`restricted(to:)`), so books sharing concept names never mix. |
| 7 | Prerequisite detection and return | delivered | `prerequisites(of:)` comes from `uses` edges. The selector detours once to a weak prerequisite when basics are failing (≥2 answers' worth). It returns after one success or three attempts, never detours twice in a row, and expires after 7 days even if no answer arrives. The `RemediationObjective` is persisted with the answer. The planner shows a detour question with the prerequisite's own passage, or leaves it out when that concept has none. |
| 8 | Retrieval practice | delivered | `RetrievalPriority` combines misconception salience, weakness, recent confident errors and forgetting; it is zero without evidence, so old plans are unchanged. Open-recall probes are attached to recall activities, the typed recall is compared with the source, and the reveal shows the sentences that answer the question. |
| 9 | Better explanation strategies | delivered | `InterventionPlanner` produces one smallest next step from fixed templates plus source or learner words. It can correct a contradiction by showing the source sentence, contrast two concepts, qualify an overgeneralisation, ask for a missing condition, cue a missing idea without revealing it, ask for a rephrase without the name, ask for the learner's own words, or deepen. Only an explanation covering every key idea is told so. A deepening contrast is offered only with a concept the source sets beside this one or its closest sibling of the same kind. Every step has a grounded follow-up question. |
| 10 | Learning continuity | delivered | The learner model lives in `LearningSnapshot` (optional key; legacy snapshots decode). Objectives and misconceptions carry over between sessions, and probes and detours survive checkpoints. |
| 11 | Failure resilience / stale requests | delivered | Repository revision plus `SnapshotRevisionGate` on every learning refresh, including the checkpoint path (defect D7) and the Lens. Evidence is committed atomically with its review and never counted twice: recent evidence is recognised by id, older evidence by a time watermark, and a Teach It Back attempt, stored in the same transaction, remembers that it was counted. A learner model this Leu cannot read (damaged, not even an object, or written by a newer Leu) is kept verbatim and never modified; the stored shape is pinned to its version by a test. A session plan is used only if no write happened while it was made. |
| 12 | Generation quality gates | delivered | `ProbeValidator` checks rubric existence, current evidence, leakage, prompt shape, unresolved references, option validity, answer ≠ distractor, distractors not named in quotes, and quoted text that would single out the answer (a word of it no distractor shares, or its acronym spelled out). `SemanticStemGate` catches malformed stems, thin descriptions and fragment options, and a set-level check drops prompts that appear twice with different answers, in fresh compiles and in stored banks. |
| 13 | Question diversity | delivered | `ProbeDiversity`: no prompt repeats until the others have been asked, the same kind of question is never asked three times running, and no duplicate probe appears within a session. |
| 14 | Confidence calibration | delivered | `CalibrationProfile` is built from objectively scored choice answers only. Confident errors raise retrieval priority, and an overconfident learner gets explanation rather than recognition questions. |
| 15 | Transfer | partial | `recognizeExample` and `applyExample` probes use only the source's own examples; there are no invented scenarios. An example that names its own answer (53 on the manual) is used only for open application questions. Transfer beyond the source's examples is deliberately not attempted. |

---

## 4. Architecture changes

```
ShelfCore/Learning/
  Intelligence/Claims/     LearningClaim (+ citation), ClaimGrounding, SourceSpan, ConceptKey
                           ConceptKnowledgeCompiler (+ ClaimAdmission, ClauseParser/Lexicon,
                           CanonicalPageIndex), ConceptKnowledgeBase (+ restricted(to:)),
                           ConceptEdgeBuilder (+ ConceptMentionIndex), ConceptKnowledgeCache
  Intelligence/Diagnosis/  Lexicon(+Tables), Proposition (polarity, negation scope,
                           universal-in-scope), Alignment(+Context), DiagnosisTarget
                           (+ contrast partner), UnderstandingDiagnoser, UnderstandingDiagnosis,
                           InterventionPlanner, DistractorAnalysis
  Intelligence/Probes/     ProbeOperation + PromptRealizer, LearningProbe, ProbeGenerator,
                           ProbeValidator, ProbeDiversity, AdaptiveProbeSelector
  Intelligence/TeachLeu/   TeachBack (V34 path; V27 validator kept as fallback)
  Memory/LearnerModel/     LearningEvidence, LearnerModelState(+Support), LearnerModelReducer,
                           RetrievalPriority, LearnerEvidenceMapper
  Persistence/             LearningRepository (+Intelligence, +LearnerModel, +Objects);
                           revision counter, SnapshotRevisionGate; the extraction migration
                           also drops ambiguous stored prompts; finished sessions drop probes
  Semantic/                SemanticQuestionCompiler (memoized), ConceptImportanceModel
                           (SourceContext), SemanticStemGate
  Sessions/                ShelfStudySessionPlanner (knowledge-aware, per-document, multi-pass,
                           lazy probes)
Shelf/Learning/            LearningModel+Adaptive, LearningModel+Feelings (new); small edits
                           listed in §5
```

Boundaries:
* **Derived vs owned data.** The knowledge base is derived: compiled from the analysis,
  cached in memory by extraction fingerprint, and never persisted. The learner model is
  learner-owned and persisted in the existing snapshot file, inside the existing
  single-transaction write path. No new file or format was added.
* **One document per lookup.** Concept names repeat across books ("Cache"), and knowledge
  lookups are by name. Anything that asks about a concept works on one document's
  knowledge: the planner builds its mapper and selector per document, and the app reads
  answers against the answered document's own knowledge. Merged knowledge is only a
  container.
* **Where the logic lives.** ShelfCore holds all logic and is Foundation-only. The app
  calls pure functions and the repository actor; session planning runs in a detached task.
* **The V3 contract is untouched,** so persisted V3 questions still re-admit identically.
* **Deviation from the plan.** The plan expected literal claims to come from the V2/V3
  extractor. The concept compiler instead has its own conservative clause parser: the V3
  extractor refuses definitional fragments by design, and its contract had to stay intact.

---

## 5. Files changed

**ShelfCore — claims & knowledge**

- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Claims/CanonicalPageIndex.swift` — new, 176 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Claims/ClaimAdmission.swift` — new, 111 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Claims/ClauseLexicon.swift` — new, 123 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Claims/ClauseParser.swift` — new, 249 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Claims/ConceptEdgeBuilder.swift` — new, 177 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Claims/ConceptKnowledgeBase.swift` — new, 136 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Claims/ConceptKnowledgeCache.swift` — new, 36 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Claims/ConceptKnowledgeCompiler.swift` — new, 213 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Claims/LearningClaim.swift` — new, 172 lines

**ShelfCore — diagnosis**

- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Diagnosis/Alignment.swift` — new, 170 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Diagnosis/AlignmentContext.swift` — new, 105 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Diagnosis/DiagnosisTarget.swift` — new, 223 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Diagnosis/DistractorAnalysis.swift` — new, 56 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Diagnosis/InterventionPlanner.swift` — new, 177 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Diagnosis/Lexicon.swift` — new, 207 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Diagnosis/LexiconTables.swift` — new, 190 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Diagnosis/Proposition.swift` — new, 164 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Diagnosis/UnderstandingDiagnoser.swift` — new, 235 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Diagnosis/UnderstandingDiagnosis.swift` — new, 112 lines

**ShelfCore — probes**

- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Probes/AdaptiveProbeSelector.swift` — new, 147 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Probes/LearningProbe.swift` — new, 74 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Probes/ProbeGenerator.swift` — new, 220 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Probes/ProbeOperation.swift` — new, 200 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Probes/ProbeValidator.swift` — new, 35 lines

**ShelfCore — Teach Leu**

- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/TeachLeu/TeachBack.swift` — new, 86 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/TeachLeu/TeachLeu.swift` — +3 / −0

**ShelfCore — learner model**

- `Packages/ShelfCore/Sources/ShelfCore/Learning/Memory/LearnerModel/LearnerEvidenceMapper.swift` — new, 194 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Memory/LearnerModel/LearnerModelReducer.swift` — new, 178 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Memory/LearnerModel/LearnerModelState.swift` — new, 190 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Memory/LearnerModel/LearnerModelSupport.swift` — new, 98 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Memory/LearnerModel/LearningEvidence.swift` — new, 96 lines

**ShelfCore — persistence**

- `Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/DerivedExtractionMigration.swift` — +7 / −1
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository+Intelligence.swift` — new, 44 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository+LearnerModel.swift` — new, 34 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository+Objects.swift` — new, 53 lines
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository.swift` — +10 / −88
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/StudyCheckpointMutation.swift` — +4 / −0

**ShelfCore — semantic bank**

- `Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/ConceptImportanceModel.swift` — +46 / −0
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/FinalMCQAdmission.swift` — +1 / −0
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticQuestionCompiler.swift` — +30 / −19
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticStemGate.swift` — new, 63 lines

**ShelfCore — sessions & domain**

- `Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/LearningSnapshot.swift` — +7 / −1
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/StudyModels.swift` — +8 / −1
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Sessions/StudySessionPlanner.swift` — +82 / −7

**ShelfCore — tests (V34)**

- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/AdaptivePlannerTests.swift` — new, 152 lines
- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/AdversarialLearningTests.swift` — new, 97 lines
- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/DiagnosisEvaluation.swift` — new, 163 lines
- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/DiagnosisSemanticsTests.swift` — new, 79 lines
- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/KnowledgeCompilerTests.swift` — new, 91 lines
- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/LearnerEvidenceTests.swift` — new, 208 lines
- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/LearnerModelTests.swift` — new, 268 lines
- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/LearningCorpus.swift` — new, 50 lines
- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/LearningQualityEvaluationTests.swift` — new, 41 lines
- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/ProbeEngineTests.swift` — new, 270 lines
- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/SemanticBankQualityTests.swift` — new, 80 lines
- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/TeachBackTests.swift` — new, 122 lines

**ShelfCore — existing tests (portability only)**

- `Packages/ShelfCore/Tests/ShelfCoreTests/Learning/V27IntelligenceTests.swift` — +7 / −0
- `Packages/ShelfCore/Tests/ShelfCoreTests/Learning/V28PersistenceTests.swift` — +4 / −3
- `Packages/ShelfCore/Tests/ShelfCoreTests/Learning/V28SourceRoleTests.swift` — +1 / −1

**Fixtures**

- `Packages/ShelfCore/Tests/Fixtures/leu-real-corpus.json` — new, 1534 lines
- `Packages/ShelfCore/Tests/Fixtures/tools/build_corpus.py` — new, 131 lines
- `Packages/ShelfCore/Tests/Fixtures/understanding-diagnosis-cases.json` — new, 1606 lines

**App (Shelf)**

- `Shelf/Features/Reader/ReaderModel+Lens.swift` — +1 / −1
- `Shelf/Learning/ConnectionsSheet.swift` — +1 / −1
- `Shelf/Learning/Intelligence/ReaderIntelligenceModel.swift` — +30 / −3
- `Shelf/Learning/Intelligence/TeachLeuSheet.swift` — +7 / −0
- `Shelf/Learning/LearningModel+Adaptive.swift` — new, 142 lines
- `Shelf/Learning/LearningModel+Feelings.swift` — new, 45 lines
- `Shelf/Learning/LearningModel+Intelligence.swift` — +3 / −2
- `Shelf/Learning/LearningModel+Objects.swift` — +6 / −6
- `Shelf/Learning/LearningModel+Recovery.swift` — +4 / −3
- `Shelf/Learning/LearningModel+Sessions.swift` — +19 / −56
- `Shelf/Learning/LearningModel.swift` — +15 / −2
- `Shelf/Learning/QuestionFeedbackView.swift` — +7 / −0
- `Shelf/Learning/RecallCardView.swift` — +18 / −6
- `Shelf/Learning/TrailDetailScreen.swift` — +1 / −1

**Project & docs**

- `Shelf.xcodeproj/project.pbxproj` — +8 / −0
- `docs/LEU_V34_CAPABILITY_PLAN.md` — new, 227 lines
- `docs/LEU_V34_CAPABILITY_REPORT.md` — new, 683 lines
- `docs/internal/evidence/project-manifest.json` — +10 / −0

---

## 6. Learning-quality improvements

**Method.** 92 learner explanations were labeled before any V34 code existed
(`Tests/Fixtures/understanding-diagnosis-cases.json`): 49 dev, 43 held-out. The texts come
from real documents already in the repository (`Tests/Fixtures/leu-real-corpus.json`,
rebuilt by `tools/build_corpus.py` from those PDFs). Each case labels which claims are
covered, partial or contradicted, and which issues must or may be reported. A case counts
as *actionable* only if every labeled claim is right (covered/partial equivalence
allowed), every required issue is found, and there is no false issue and no false claim
alignment. The V27 validator stays runnable on the same cases.

**Discipline.** Dev was used for tuning. The held-out split was run blind exactly once
(official: 56% actionable vs V27 14%). That run exposed a general flaw: polarity was
judged per claim rather than per proposition. The fixes are general mechanisms, not case
patches:
* proposition-level polarity;
* negation scope that the other side must cover;
* "not for every X" is only contradicted by a universal;
* negative verbs (avoid, prevent, …) instead of an antonym dimension;
* `, not` contrasts keep their negation;
* a leading "Without X," is its own proposition;
* one misconception per clause;
* confusion needs substantive rival evidence;
* circularity needs the concept's head word.

Later held-out runs are reported as **non-blind**. Labels were never changed.

**A deliberate loss.** The independent review showed that resolving "It" to the previous
sentence's subject invented facts on the manual ("A callback explains many React bugs" on
the Stale closure card, "A module prevents unrelated concerns …"). No syntactic rule tells
those apart from the correct cases ("Time complexity describes … It does not predict the
exact time …"), so the path was removed. Three labeled cases needed it (`dev-state-01`,
`dev-state-02`, `ho-cs-01`), which moved dev from 94% to 92% and the non-blind held-out
score from 77% to 74%. Leu now misses those sentences instead of risking wrong ones.

Three remaining held-out failures are label omissions rather than system errors, and are
still counted: `ho-jwt-02` and `ho-cors-02` align the conflict with exactly the claim the
case contradicts, and `ho-hash-01` credits the learner's correct statement about salted
password hashing.

**What remains wrong on held-out (honest list).**
* Paraphrases outside the lexicon: "knowing who someone is" for identity, "only once" for
  non-repeatability.
* A confusion not detected ("Authentication decides what a user is allowed to do": 67%
  rival evidence, below the 75% bar).
* One contradiction reported where the label expected only a confusion.
* A cross-clause "otherwise".
* A pronoun after a non-heading subject (`ho-cs-01`, above).

**Other quality gains.**
* Concept-card pages (the manual's main format) can be taught back at all; before, the
  comparison could not run on them (D1).
* Typed recall is compared with the source (D2), and the reveal shows the sentences that
  answer the question.
* A chosen wrong option that traces to another concept, or to a reversed source sentence,
  is explained and remembered (D3).
* Grounded probes cover 79% of cards with a varied set, and every quoted definition or
  example was checked against its own answer.
* 99 malformed or ambiguous legacy questions no longer reach learners.

---

## 7. Reliability improvements

* **D7 stale snapshots.** The repository now keeps a revision, and every learning-model
  refresh goes through `SnapshotRevisionGate`: 20 call sites, plus the checkpoint path
  that could overwrite a newer rating.
* **Main actor.** Session planning and answer analysis run off the main actor: tracing a
  wrong option, comparing typed recall, and turning an answer into evidence. A result is
  applied only if the learner is still on the same activity. A second tap on *Start*
  while planning is ignored. A plan is kept only if the repository revision it was made
  from is still current when it is ready and is the snapshot on screen; indexing, an
  upsert or a refresh during planning discards it and planning starts again (at most three
  times, then the learner is asked to start again). An outdated plan never begins.
* **Atomicity and idempotency.** Evidence is applied in the same transaction as its
  review; a failed save keeps neither (tested). The learner model remembers the last 400
  applied evidence ids; evidence older than any id it has forgotten is refused by a time
  watermark, so replaying an old answer after any number of later ones never counts it
  again, and the record stays bounded. A Teach It Back attempt is stored in the same
  transaction as its evidence and remembers that it was counted, so comparing it again,
  however much later, adds nothing. One answer yields one observation, and evidence for
  removed documents is ignored. The watermark assumes the device clock does not move
  backwards past it; evidence dated earlier than already forgotten evidence is refused.
* **Persistence safety.**
  * Legacy snapshots decode with an empty learner model.
  * A learner model this Leu cannot read is kept verbatim and never modified: a
    malformed field, a malformed version, a value that is not an object at all
    ("corrupt", `[1, 2, 3]`), or a model written by a newer Leu. A missing or null model
    (a legacy snapshot) becomes an empty, writable one. A test pins the stored shape to the model's version, so
    a future change must bump it.
  * StudySession checkpoints written before V34 still resume; finished sessions are
    stored without their questions, keeping history small.
  * All collections are bounded.
* **Documents stay apart.** Two books with the same concept names produce the same
  questions for each as each would alone (tested with a duplicate of the manual).
* **Determinism.**
  * The concept graph depended on dictionary hash order (458–460 edges across runs).
    It is now fixed at one output.
  * Session planning broke score ties with random UUIDs; ties now keep source order.
  * Merged knowledge in the app is built in document order.
  * "Distinct days" are the learner's local days (device time zone), by design.
* **Planner robustness.** Selection was single-pass, so when few questions existed a
  30-minute session held 3 activities. Selection is now multi-pass: kinds still
  alternate while possible, and no passage repeats.
* **Structural validation.** It failed at the base commit (a 310-line
  `LearningRepository.swift` over the 300-line boundary; a manifest missing 7 app files
  and 1 UI test). It now passes, the repository split into cohesive extensions.

---

## 8. Performance comparison

Linux x86-64, Swift 6.1.3, debug builds unless noted; release figures in brackets. Device
builds will differ; no device numbers are claimed.

| Operation (345-page manual unless noted) | Before | After |
|---|---|---|
| Semantic index + question bank | 91.9 s | 9.2 s (identical output, md5-verified) |
| — question bank only | 86.9 s | 4.2 s |
| Knowledge compile (new) | first version 4.3 s | 2.3 s [1.3 s] |
| Single-page knowledge (Teach Leu availability check) | — | 7 ms |
| Probes for all 315 cards (1 096 probes, 351 multiple choice) | — | 5.8 s (≈18 ms per card) |
| Plan a 30-minute session, same snapshot | 0.47–0.61 s [0.20 s], 3 activities, on the main actor | 1.0 s [0.49–0.58 s], 25 activities, 22 with a grounded question, off the main actor |
| — with six books sharing concept names | — | 1.05 s [0.47–0.57 s]: no growth with library size |
| Diagnose one explanation (concept card with neighbours) | — | ≈0.1 s; input bounded to 4 000 characters |
| Trace a chosen wrong option to the source | — | 0.33 s for a sentence option, 4 ms for a concept name; off the main actor |
| Full ShelfCore test suite | 24.6 s (320 tests) | 121 s (423 tests; corpus-level quality tests included) |

Planning does more work than before (it chooses and checks a grounded question for each
activity), but the learner no longer waits on it: before V34 the whole plan ran on the
main actor.

---

## 9. Test results

* ShelfCore: **423 tests, 0 failures**, on a clean build with 0 warnings.
  New tests (103):

  | Suite | Tests | Covers |
  |---|---|---|
  | LearnerModelTests | 23 | every unreadable learner model preserved verbatim (malformed, not an object, future) while missing/null starts empty, old evidence refused after the id record moved on, mastery vs one lucky answer, spacing vs cramming, decay, capped levels, misconception retirement on two distinct days, retirement only by checked answers about the same idea, confusion retired only by telling the same pair apart, salience decay, retrieval priority, calibration, idempotency, detour return, bounds, legacy/unreadable/future-version models, stored shape pinned to the version |
  | LearnerEvidenceTests + LearnerRepositoryTests | 15 | a plan made while the library changed is never used, a Teach It Back attempt counts once even after 450 later answers, question → concept, sibling choice → confusion, reversed sentence → contradiction, untraceable distractor → nothing, explanation → evidence, one recall = one observation, same attempt counted once, self-rating at half weight, atomic commit with review, failed save keeps nothing, retries counted once, stale snapshot rejected, detour persisted only for known documents |
  | ProbeEngineTests | 14 | every probe on the manual grounded, answerable and leak-free (an independent check that no quote contains the answer's own words), rejection of ungrounded, stale and leaking probes, natural prompts for every name shape (HTTP, "never", Title Case names, clausal subjects), open probes graded against their own rubric, scripted learners (new concept climbs, misconception retested until retired, confusion retired through the selector's own contrasts, prerequisite detour and return, abandoned detour expires, overconfidence → explanation, variety) |
  | AdaptivePlannerTests | 7 | no knowledge = exactly the old plan, misconception first, no repeats, question matches its passage and the reveal holds its answer, a second book with the same names changes nothing, checkpoint round trip, finished sessions stored without questions |
  | SemanticBankQualityTests | 7 | baseline malformed stems rejected, good stems kept, ambiguous prompts dropped in fresh and stored banks, V3 untouched, manual bank fast and deterministic |
  | TeachBackTests | 9 | concept cards teachable where V27 could not run, missing idea cued without revealing it, keyword lists and partial ideas never called complete, verbatim copy asked for own words with partial credit only, feedback quotes only the source's words, wrong explanation shown beside the source sentence, stored results bound to their explanation and source, fallback to V27, single-page availability |
  | LearningQualityEvaluationTests | 3 | dev/held-out thresholds against the labeled fixture, card coverage |
  | DiagnosisSemanticsTests | 7 | per-proposition polarity, negative verbs and contrasts, negation scope, universal quantifiers, confusion and circularity thresholds, deepening contrasts only with a concept worth telling apart |
  | KnowledgeCompilerTests | 9 | subject admission, noun/verb homographs, relative clauses without "that", pronouns resolved only to their own heading, acronym aliases, code examples, deterministic whole-name graph, contrast evidence, compile time |
  | AdversarialLearningTests | 9 | empty/degenerate input, 325 000-character input (bounded in time), prompt-injection text, other languages, degraded documents, unknown IDs, same names in two documents, blank/duplicate options, very large learner model |

* Existing tests: all 320 still pass, and none was weakened or deleted. The only edits
  are portability fixes needed to compile the test target on Linux:
  * a CryptoKit digest comparison became byte equality, which is stricter;
  * `V27IntelligenceTests()` instantiation was replaced by a static fixture builder.
* `scripts/validate.py`: **PASS** (it failed at the base commit).
* `scripts/check-*.py`: the same pass/fail set as the base commit (9 pass, 6 pre-existing
  failures). Their output was diffed against the base commit, and V34 adds no new
  violation. In `check-learning-architecture.py` it removes two existing ones:
  `LearningRepository.swift` went from 310 to 232 lines and `LearningModel+Sessions.swift`
  from 267 to 230. What remains are three untouched UI files and a missing copy token.
* **App target.** It cannot be compiled on Linux (SwiftUI, PDFKit and FoundationModels).
  Every edited app file passes `swiftc -parse`. The new app code and the edited call
  sites were also compiled against the real ShelfCore in a scratch harness with a
  stand-in `LearningModel`, under `-strict-concurrency=complete`: no errors, no
  warnings. UI tests were not run; they already wait up to 12 s for the session screen,
  which now appears once the off-main plan is ready. The one UI journey that reads Teach
  Leu output was replayed in ShelfCore: V34 still yields both *You captured* and *Worth
  adding* for it.

---

## 10. Known limitations

* **Diagnosis limits.**
  * It is lexical (stems, curated paraphrase families, opposite-meaning dimensions,
    polarity and scope). It is labelled as such and never claims entailment. Unseen
    paraphrases are missed and reported as "not settled", not as wrong.
  * The lexicon is English only.
  * Only the first held-out run was blind (56%); 74% is a non-blind re-run.
* **Pronouns.** "It"/"They" is resolved only to the heading a sentence sits under. After
  any other subject the sentence yields no claim, so some true statements are not
  compared (three labeled cases).
* **Study objects.** In the repository's corpus, only 150 of 1,021 study objects pass the
  existing `studyObjects` source-integrity filter, because reconstructed segment text
  differs from PDFKit canonical text in hyphenation and spacing. Concepts whose passages
  are filtered cannot be scheduled by the planner. This is baseline behaviour; the app on
  device may differ, and it was not changed.
* **Probes.**
  * Prompts are templates over source words. Some are stiff ("What does a distributed
    cache give?").
  * Sibling contrasts without an explicit source contrast rely on a shared-genus
    heuristic; concepts without one get no contrast question.
  * An example that names its own answer is not used for recognition.
* **Evidence.**
  * Self-rated recall is evidence at half weight: the learner's own read, not a verdict.
  * Teach It Back counts the first comparison of each attempt; later comparisons of the
    same attempt, made after seeing the source, add nothing.
  * Evidence dated earlier than evidence the learner model has already forgotten by id
    is refused (a clock set backwards could drop a genuine answer).
* **Legacy code kept.** V27's hardcoded React identity paraphrase and `ActivityValidator`
  are unchanged. V34 supersedes the former on the product path, but it is kept for V27's
  contract tests and as a fallback. `ActivityValidator` still recognises two literal
  pages (D9 partially addressed).
* **No device measurements.** Performance is Linux debug and release. App and UI
  behaviour were not exercised on a simulator or device.

---

## 11. Deferred opportunities

* **Paraphrase proposals.** Use Apple's on-device Foundation Models (free, local) only
  to *propose* paraphrase alignments, each re-verified against the grounded rubric, as
  V27 already does for Teach Leu pairs. The same verified-proposal route could recover
  pronouns that follow a non-heading subject.
* **Similarity evidence.** `NaturalLanguage` sentence embeddings (on-device) as a third
  evidence tier, calibrated on the dev split before use.
* **Source-integrity reconciliation.** Reconcile reconstructed segments with canonical
  text (hyphenation, spacing) so more study objects pass the filter.
* **Explicit prerequisites.** Mine explicit dependency phrasing ("requires", "builds on")
  and link concepts across documents.
* **Probe scheduling.** Per-operation spacing (FSRS-style) for probes, unified with
  `ShelfReviewScheduler`.
* **Learner insight UI.** A learner-facing view of the model, deliberately not built:
  the brief forbids new dashboards.

---

## 12. Exact git status

Immediately before the commit (`git status --short --branch`), the working tree held
exactly the changes listed in §5 and nothing else:

```
## claude/leu-v34-capability-upgrade
 M Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/LearningSnapshot.swift
 M Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/StudyModels.swift
 M Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/TeachLeu/TeachLeu.swift
 M Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/DerivedExtractionMigration.swift
 M Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository.swift
 M Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/StudyCheckpointMutation.swift
 M Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/ConceptImportanceModel.swift
 M Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/FinalMCQAdmission.swift
 M Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticQuestionCompiler.swift
 M Packages/ShelfCore/Sources/ShelfCore/Learning/Sessions/StudySessionPlanner.swift
 M Packages/ShelfCore/Tests/ShelfCoreTests/Learning/V27IntelligenceTests.swift
 M Packages/ShelfCore/Tests/ShelfCoreTests/Learning/V28PersistenceTests.swift
 M Packages/ShelfCore/Tests/ShelfCoreTests/Learning/V28SourceRoleTests.swift
 M Shelf.xcodeproj/project.pbxproj
 M Shelf/Features/Reader/ReaderModel+Lens.swift
 M Shelf/Learning/ConnectionsSheet.swift
 M Shelf/Learning/Intelligence/ReaderIntelligenceModel.swift
 M Shelf/Learning/Intelligence/TeachLeuSheet.swift
 M Shelf/Learning/LearningModel+Intelligence.swift
 M Shelf/Learning/LearningModel+Objects.swift
 M Shelf/Learning/LearningModel+Recovery.swift
 M Shelf/Learning/LearningModel+Sessions.swift
 M Shelf/Learning/LearningModel.swift
 M Shelf/Learning/QuestionFeedbackView.swift
 M Shelf/Learning/RecallCardView.swift
 M Shelf/Learning/TrailDetailScreen.swift
 M docs/internal/evidence/project-manifest.json
?? Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Claims/
?? Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Diagnosis/
?? Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/Probes/
?? Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/TeachLeu/TeachBack.swift
?? Packages/ShelfCore/Sources/ShelfCore/Learning/Memory/LearnerModel/
?? Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository+Intelligence.swift
?? Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository+LearnerModel.swift
?? Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository+Objects.swift
?? Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticStemGate.swift
?? Packages/ShelfCore/Tests/Fixtures/
?? Packages/ShelfCore/Tests/ShelfCoreTests/V34/
?? Shelf/Learning/LearningModel+Adaptive.swift
?? Shelf/Learning/LearningModel+Feelings.swift
?? docs/LEU_V34_CAPABILITY_PLAN.md
?? docs/LEU_V34_CAPABILITY_REPORT.md
```

After the commit, `git status` reports `nothing to commit, working tree clean` on
`claude/leu-v34-capability-upgrade`. The branch has no upstream and `git push` was never
run. The terminal summary repeats the actual post-commit status.

---

## 13. Exact local commit hash

A commit cannot contain its own hash. This report is part of the single local commit on
branch `claude/leu-v34-capability-upgrade`. Its parent is
`bf7c5cbf55594821b647485cbea052343de2e505`. The commit's own hash is given in the final
terminal summary, and can be read with `git log -1 claude/leu-v34-capability-upgrade`.
Nothing was pushed.

---

## Appendix — Final adversarial review

Two passes were made over the finished work. One was my own. The other was an
independent, read-only review of the whole diff that also ran the code against the real
corpus. The independent pass found problems mine had missed. All but two minor points
were fixed before the commit; the table names the test that covers each fix:

| Finding (independent review) | Fix | Test |
|---|---|---|
| **Invented facts.** "It" resolved to the previous sentence's subject; 13 wrong claims on the manual, e.g. "A callback explains many React bugs" | "It"/"They" resolve only right after the heading's own subject. Relative clauses without "that" are read as fragments. Quotation marks hold only the source's words, and an inferred subject is named outside them | KnowledgeCompilerTests, TeachBackTests |
| **Overlap shown as understanding.** A keyword list got *You captured* lines, "matches each key idea", and correct evidence | Keyword lists earn nothing. "Covers each key idea" only when every claim is covered. Partly covered ideas are *worth adding*. Correct evidence requires full coverage | TeachBackTests |
| **Choice questions leaked answers** through quoted examples (`SELECT … JOIN` for SQL JOIN, "should never occur" for `never`) | Quoted text may not contain a word of the answer that no distractor shares, nor spell its acronym | ProbeEngineTests (independent check over every probe) |
| **Misconceptions retired without evidence:** two "Knew it" ratings, or a check about another claim | Corrections must be checked answers about the same claim. A confusion retires only when the same two concepts are told apart | LearnerModelTests, ProbeEngineTests |
| **One answer counted twice** (typed recall plus rating); Teach It Back re-comparisons inflated mastery | One observation per answer; evidence keyed to the attempt | LearnerEvidenceTests |
| **The recall reveal showed a page header**, not the answer (0 of 22 planned questions) | The reveal and *View in PDF* show the question's own source sentences | AdaptivePlannerTests (the answer text); the view change is type-checked only |
| **Knowledge lookups ignored the document:** a second book's questions fell from 3 to 1 per concept | Per-document knowledge in the planner and the app | AdaptivePlannerTests |
| Minor: alphabetical contrast partner ("How does a foreign key differ from ACID?"), "an HTTP", "a never", "a single Responsibility Principle", clausal subjects | Contrast only with an explicit or same-kind partner. Acronyms are counted by their own plural; lowercase keywords are quoted; Title Case names take "the". Clausal subjects are refused | DiagnosisSemanticsTests, ProbeEngineTests |
| Minor: "Earlier you wrote" for an option the learner only picked | "Earlier you answered" | — (wording) |
| Minor: one ungated snapshot write (Lens) | Goes through the revision gate | harness type-check |
| Minor: stored Teach It Back results not bound to their explanation or to the heading a subject came from | Both are checked on re-admission | TeachBackTests |
| Minor: an unreadable learner model was reset and then overwritten | Kept verbatim, never modified; stored shape pinned to the version | LearnerModelTests |
| Minor: saved sessions grew 4×, and are kept forever | Finished sessions drop their questions | AdaptivePlannerTests |
| Minor: a detour expired only when a new answer arrived | Expires by age in the selector | ProbeEngineTests |
| Minor: the ambiguous-prompt filter did not reach banks already stored | Applied by the existing extraction migration | SemanticBankQualityTests |
| Minor: planning took ≈1 s on the main actor, growing with library size | Off the main actor; per-document knowledge removed the growth | measured, §8 |
| Minor: `setRemediationObjective` was unused | Removed; detours are installed only with the answer that starts them | LearnerRepositoryTests |

One point was reviewed and deliberately left as it is: "distinct days" follow the device
time zone, because they are the learner's days. (Teach It Back evidence and its attempt,
first left in separate transactions, are now saved together; see the follow-up audit.)

**Follow-up audit (after the handoff branch).** An independent audit of the pushed branch
found three more problems. All are fixed, each with a regression test:

| Finding | Fix | Test |
|---|---|---|
| An off-main session plan could begin after indexing or a refresh had changed the snapshot it was made from | `CurrentStudyPlan` plans from the repository's revisioned snapshot and keeps the plan only if the revision is unchanged when planning ends; the app also requires that revision to be the one on screen, re-plans otherwise, and never begins an outdated plan | LearnerRepositoryTests (a write during planning forces a re-plan; constant writes yield no plan) |
| Evidence idempotency covered only the last 400 ids | A time watermark refuses evidence older than any forgotten id; Teach It Back attempts record that they were counted, in the same transaction as their evidence | LearnerModelTests (old evidence replayed after 450 later answers), LearnerRepositoryTests (an attempt re-compared after 450 answers) |
| A learner model that was valid JSON but not an object (`"corrupt"`, `[1,2,3]`) fell back to a new writable model and could be overwritten | Any present but unreadable value is preserved verbatim; only missing or null becomes an empty writable model | LearnerModelTests (malformed field, malformed version, future version, string, array, number, missing, null) |

Files changed by the follow-up (a second local commit on the same branch; §5 and §12 describe the first):

- `Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/UnderstandingMemory/IntelligenceSource.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Memory/LearnerModel/LearnerModelReducer.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Memory/LearnerModel/LearnerModelState.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository+Intelligence.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Sessions/CurrentStudyPlan.swift`
- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/LearnerEvidenceTests.swift`
- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/LearnerModelPersistenceTests.swift` (new: storage tests split out to stay under the 300-line file boundary)
- `Packages/ShelfCore/Tests/ShelfCoreTests/V34/LearnerModelTests.swift`
- `Shelf/Learning/Intelligence/ReaderIntelligenceModel.swift`
- `Shelf/Learning/LearningModel+Sessions.swift`
- `docs/LEU_V34_CAPABILITY_REPORT.md`

**As a staff engineer**

* **What is fragile?** The lexicon tables (paraphrase families, opposite-meaning
  dimensions, negative verbs) and the clause parser's noun/verb heuristics. Both are
  tuned on three technical documents. Failure is conservative: an unrecognised paraphrase
  is reported as *not settled*, never as wrong, and a sentence the parser cannot read, or
  a pronoun it cannot place, yields no claim rather than a guessed one. The study-object
  integrity filter (baseline) still decides which concepts the planner can schedule.
* **What is over-engineered?** Preserving a learner model this Leu cannot read
  (`PreservedJSON`) is the most speculative piece. It is small, and it prevents a real
  data loss after a downgrade or a damaged save, so it stays. Ten probe operations is at
  the upper edge: `define` and `recognizeDefinition` differ only in direction.
* **What is pretending to be intelligent?** Less than before the review, which found two
  real cases: lexical overlap presented as understanding, and pronouns resolved by
  guesswork. Both are fixed. Diagnosis is lexical and says so (`exact`/`lexical`
  evidence tiers; no "entailment"). Prompts are templates over source words and
  sometimes read stiffly. The sibling contrast chooses a partner by shared genus and
  vocabulary, which is a heuristic; its answer is still judged against the two concepts'
  own source definitions.
* **Where can stale state occur?** Snapshot refreshes are revision-gated (the Lens was
  the last exception). In-flight analysis of an answer is applied only to the same
  activity, and an off-main plan starts a session only if none has started meanwhile.
  Teach Leu results are re-admitted only for their own explanation while their sources
  are current. The knowledge cache is keyed by document fingerprint, extraction version
  and compiler version. What remains: if a document is re-analysed in the middle of a
  session, answers to its remaining probes are recorded against concept keys that may no
  longer exist. Those entries stay inert, because planning reads only current knowledge,
  until the least-recently-seen bound (2 000 concepts) removes them; nothing wrong is
  shown. As with the existing analyses, attempts and reviews, a trashed book's learner
  entries are kept, so restoring the book restores its progress.
* **What is insufficiently tested?** The SwiftUI wiring: it was type-checked against a
  stand-in, not built, and no UI test ran. Documents unlike the corpus (other layouts,
  other languages). Months of real use: the learner model is exercised by scripted
  learners, not by people.
* **Which abstraction will become painful?** `ProbeOperation` is switched over in the
  generator, validator, selector and evidence mapper, so a new operation touches four
  files, and now also the pinned stored shape (by design). Probes reach the existing UI as
  ephemeral `LearningQuestion`s (`probe.question`); this seam avoided a redesign, but two
  question models now coexist. The lexicon tables will grow and should move to a data
  file with the evaluation harness as their gate. `ConceptKnowledgeBase` lookups are by
  name and correct only within one document; the rule is documented and tested, but a
  document-keyed API would make it impossible to break.
* **Which feature does not genuinely improve learning?** Calibration has one consequence
  (overconfident learners get open questions) and needs six scored choice answers before
  it acts, so its effect is small. Diversity mostly prevents annoyance. Both are kept
  because they are cheap and tested.
* **Where does generation failure create incorrect behaviour?** When a concept has no
  valid probe, the planner uses the existing question or recall card; with no knowledge
  the plan is exactly the old plan (tested). When knowledge cannot be compiled, Teach Leu
  uses the V27 comparison. Too-short input, nonsense and keyword lists record no
  evidence. The residual risk is a false contradiction (2 dev and 3 held-out false issue
  flags): it records a misconception the learner does not hold. Its cost is a retest
  question, and it retires after checked correct answers on two days.
* **Where could Leu teach something unsupported by its source?** Every sentence in
  quotation marks is an exact span, and validation refuses a probe whose rubric claim or
  evidence is missing or stale (tested). The remaining inference is subject resolution,
  now limited to the heading a sentence sits under: a definitional fragment directly
  below it, or a leading "It"/"They" right after the heading's own subject. The heading
  is stored with the claim and named outside the quotation marks. This is the one place
  Leu interprets rather than quotes, and it is the narrowest form of it.

**As a demanding learner**

* **Does Leu understand what I got wrong?** For contradictions, reversed causes,
  overgeneralisations, a missing condition and confusion with a named concept: yes, and
  it shows the source sentence beside my words. A paraphrase outside its vocabulary is
  left *not settled* rather than judged. A list of keywords is not taken for an
  explanation.
* **Does it repeat itself?** No prompt repeats until the others have been asked, the same
  kind of question never comes three times running, and 99 duplicate or ambiguous legacy
  questions are gone.
* **Does it remember previous struggles?** Yes: misconceptions are kept in my own words,
  come first in the next session, and retire only after I answer correctly, in a way Leu
  can check, on two different days. Saying "Knew it" is not enough.
* **Does it choose useful next questions?** It retests live misconceptions first, climbs
  from recognition to explanation to application as I succeed, and asks me to explain
  when my confidence outruns my results. It does not hand me the answer inside the
  question.
* **Can it bring me back from a prerequisite gap?** Once per objective: it detours to a
  weak prerequisite that the concept's own source claims name, then returns, and a
  forgotten detour ends after a week. It only knows dependencies the text makes visible
  that way (416 `uses` edges in the manual).
* **Can I trust its explanation?** The source sentences are quoted exactly; Leu's own
  words are short fixed templates around them. It does not write explanations. After a
  recall, it shows the sentences that answer the question, not merely the page I was on.
* **Does it feel noticeably smarter?** On the manual's concept cards, Teach Leu went from
  unable to run to comparing 308 of 315 cards; a 30-minute session went from 3 activities
  to 25, most with a grounded question chosen for me. The prompts can still sound
  mechanical.
