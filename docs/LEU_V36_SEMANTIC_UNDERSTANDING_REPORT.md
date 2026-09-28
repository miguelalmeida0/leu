# Leu V36 — Semantic Understanding

Branch `claude/leu-v36-semantic-understanding`, one local commit on top of the verified V35
commit `759dc88c90b14765f0c9352e4c4eadce47cf256b`. Not merged, not pushed.

Every number below comes from a run on this branch, or on a pristine checkout of V35
(`759dc88`) in the same container. Anything not measured is marked as such. The sealed V36
split was written after the reader was frozen and scored once; §11 records the order of
events, including two small changes made after that scoring.

---

## 1. Summary

**The question.** Can Leu read explanations written in genuinely new language better, using
meaning and not only shared words, without giving up any V35 safety property?

**What was built.**

* **A hybrid reader.** A bundled, deterministic word-level semantic space (vectors distilled
  from `sentence-transformers/all-MiniLM-L6-v2`, 8 MB, integer arithmetic) now feeds
  evidence to the unchanged V35 judgement.
* **Semantic evidence never writes to the learner model.**
  * It can credit what a clause says in other words, but that credit is always asked about
    before anything is recorded.
  * It can raise doubts (a reversed sense, another concept's wording, a reason the source
    does not give). Each doubt asks a question and records nothing.
  * Every V35 negation, contradiction, reversal and scope check vetoes it.

**What the evidence says.**

* **On the fresh sealed split, V36 does not read new language better.**
  * The split has 160 explanations by four new authors, in four voices, across seven documents.
  * Coarse accuracy is **52% → 51%**.
  * Paraphrase accuracy is **29% → 29%**, and novel-vocabulary accuracy **51% → 51%**.
  * Only **5 of 160** answers are judged differently at all.
* **It is marginally safer there, with no safety regression.**
  * False mastery: **11 → 10**.
  * Credited misconceptions: **10 → 9**.
  * Harmful writes: **25 → 23**.
  * Wrong commits: **21 → 20**.
  * Calibration improves slightly: Brier **0.246 → 0.242**, ECE **0.055 → 0.043**.
* **On the development splits the gains are larger.** These splits were used to build and
  calibrate the reader, so this is not evidence of generalization. On dev2 (three authors):
  * Coarse accuracy: **41% → 44%**.
  * Credited misconceptions: **10 → 7**.
  * Harmful writes: **17 → 13**.
  * Wrong commits: **18 → 13**.
* **Weak reasoning is still not recognised on new language: 0 of 16 on sealed.** On the
  development splits it found 3 of 24 (V35: 0).
* **Teach It Back improved automatically on development data.** It uses the same reader and
  no new feature. On the sealed card passages it is unchanged apart from calibration.
* **Why the gain is small.** It is a finding of this cycle, not a tuning problem.
  * A static word-level space does not carry the paraphrases learners actually write:
    * "bindings" / "variables": cosine 0.09.
    * "a brief lifespan limits the harm" against "short lifetimes reduce damage": recall 0.23.
  * On independently written text, word-level semantic recall barely separates credited from
    uncredited claims:
    * AUC **0.64** on dev2, against **0.82** on the V35 dev split it was first measured on.
  * Case-level semantic overlap separates understood answers from weak ones on dev
    (AUC 0.84) but not on dev2 (AUC 0.42). There, misconceptions overlap the source more
    than correct answers do.

**The honest one-line verdict.** V36 is a safe, inspectable semantic evidence layer that
catches a few more wrong ideas and asks better questions. It does **not** make Leu read
genuinely new language materially better, so by the brief's own criterion V36 does not
succeed on understanding meaning. §26 names the change that would.

---

## 2–4. Branch, files and Apple toolchain

* **Branch:** `claude/leu-v36-semantic-understanding`, created at `759dc88`.
* **HEAD:** the single V36 commit on that branch; its hash is given in the hand-off message.
* **Files changed:**

| Area | Files |
|---|---|
| Semantic reader (new) | `Semantics/SemanticSpace.swift`, `SemanticAntonyms.swift`, `SemanticMatcher.swift`, `SemanticGate.swift`, `SemanticReader.swift`, `SemanticThresholds.swift`; `Judgement/JudgementReading+Semantic.swift` |
| Bundled data (new) | `Resources/SemanticSpace/minilm-static-256.leusem` (8,045,167 B, sha256 `c6712167…c99c6b`), `Resources/SemanticSpace/wordnet-antonyms.txt` (19,934 pairs, WordNet notice in its header) |
| Wiring (changed) | `Package.swift` (resources), `Diagnosis/UnderstandingDiagnoser.swift` (optional semantic space; semantic readings of unsettled clauses; reasons), `Diagnosis/DiagnosisSignals.swift` (transient fields), `Diagnosis/Proposition.swift` (polarity-cue count, restrictive flag), `Judgement/UnderstandingJudge.swift`, `Judgement/UnderstandingJudgement.swift` (two cues), `Diagnosis/InterventionPlanner.swift` (weak-reasoning question wording) |
| Moved, unchanged | `Diagnosis/UnderstandingDiagnoser+Rules.swift`: four static helpers moved out of the diagnoser, which is now 228 lines, back under the repo's 250-line scrutiny boundary it already exceeded in V35 |
| Tests (new) | `V36/SemanticSpaceTests`, `SemanticGateTests`, `SemanticAdversarialTests`, `SemanticGeneralizationTests`, `TeachItBackSemanticTests` |
| Harness (changed) | `V35/GeneralizationPredictors.swift`: `v35` now reads words only (reproduces V35 exactly), `v36` added. `V35/GeneralizationEvaluation.swift`: weak-reasoning and harmful-write metrics |
| Fixtures (new) | `diagnosis-generalization-dev2.json` (120 cases, authors C/D/E), `diagnosis-generalization-sealed36.json` (160 cases, authors F/G/H/I), `diagnosis-generalization-guide-v36-addendum.md` |
| Scripts, notices | `scripts/build-semantic-space.py` (reproducible build of both data files), `scripts/v36-natural-language-probe.swift` (Mac probe, not run), `THIRD_PARTY_NOTICES.md` |

* **Apple toolchain verification: not possible in this environment.**
  * The container is Linux x86-64 with Swift 6.1.3. It has no macOS, Xcode, iOS SDK or
    simulator.
  * The real app was **not** built and no app or UI tests were run on Apple platforms. That
    has to happen on a Mac before this branch is trusted in the app.
* **What was verified instead:**
  * ShelfCore builds with 0 warnings from empty build artifacts, and its full suite passes (§22).
  * The Xcode project references ShelfCore as a local Swift package product
    (`XCLocalSwiftPackageReference "Packages/ShelfCore"`). SwiftPM resources (`Bundle.module`)
    are therefore embedded in the app as a resource bundle. This is standard SwiftPM
    behaviour, but it was not exercised in an Xcode build here.
  * No app source references a type whose shape V36 changed. The two new
    `UnderstandingCue` cases are not switched over anywhere in `Shelf/`.
  * The V35 app-level compile harness (ShelfCore plus app learning code, strict concurrency)
    still builds (§23).
  * The structural validator passes (§23).
* **Apple-only warnings:** unknown. They can only be recorded from an Xcode build.

---

## 5–6. Semantic technology, and why; deployment target

**Candidates, measured on the V35 dev split before anything was built.** Two claim strata are
used:
* **Missing:** claims V35 does not credit at all, 183 claims.
* **Partial:** claims V35 half-credits, 28 claims.

| Method | AUC, missing | AUC, partial | Runs in ShelfCore? |
|---|---|---|---|
| MiniLM contextual token alignment (ONNX) | 0.805 | 0.918 | No: needs a model runtime |
| MiniLM contextual sentence cosine | 0.664 | 0.830 | No |
| **Distilled static MiniLM word vectors (chosen)** | 0.786–0.819 | 0.833–0.854 | **Yes** |
| GloVe word alignment | 0.741 | 0.836 | Yes (larger, licence review) |

* **Sentence-level similarity was rejected outright.** It cannot tell a claim from its
  negation or reversal. The contextual sentence cosines of adversarial pairs:
  * "Authentication does not establish identity": 0.64;
  * "JWTs are signed so nobody can read them": 0.64;
  * a subject/object reversal: 0.98.
* **Apple NaturalLanguage was not assumed. It could not be tested here, and it was not
  chosen, for these reasons:**
  * `NLEmbedding` sentence vectors are sentence cosines, rejected above.
  * `NLEmbedding` word vectors are the same class of evidence as the chosen table, but their
    values can change with OS model revisions, so they are not reproducible in tests.
  * `NLContextualEmbedding` needs iOS 17 or macOS 14 (the package still supports macOS 13).
    It may need an asset download, and its floating-point output is not bit-reproducible
    across devices.
  * None of it is available on Linux, where ShelfCore is tested.
  * `scripts/v36-natural-language-probe.swift` measures all three on the brief's adversarial
    pairs and times them. **It has not been run**; it needs a Mac.
* **A contextual model inside ShelfCore was ruled out.**
  * It is the strongest method, but the repo's own contract forbids it:
    `check-learning-offline.py` rejects CoreML in learning code, and ShelfCore must stay
    dependency-free.
  * It would also mean a ~90 MB model and platform-dependent floating point.
* **The chosen space, built by `scripts/build-semantic-space.py`:**
  * Each of the model's 30,522 WordPiece pieces was encoded once, reduced to 256 dimensions
    by PCA and quantized to int8.
  * A word's vector is the integer sum of its pieces. Every similarity is an exact
    `Int64` dot product, so every platform gets bit-identical results, and tests pin them
    to 1e-12.
  * No model runs, no network is used and nothing is paid for. It is 8 MB of data.
  * Opposites sit close together in any distributional space ("fast" is closer to "slow",
    0.67, than "retain" is to "keep", 0.37). So an antonym guard (WordNet 3.0 antonyms plus
    Leu's own lexicon poles) keeps an opposite from ever counting as a paraphrase.
* **Deployment target.** Foundation only, same as before: iOS 17 / macOS 13, unchanged. No
  NaturalLanguage, CoreML or private API. The data loads through SwiftPM `Bundle.module`. If
  the resource is missing or malformed, the reader silently reads words only, exactly as V35
  did.

---

## 7–9. Architecture, responsibilities, vetoes

```
learner text ─► lexical reader (V35, unchanged) ─► stored diagnosis (unchanged)
      │                  │
      │                  └─► clause signals ─┐
      └─► semantic reader (V36) ─────────────┤  evidence only, transient
             SemanticMatcher: word stand-ins │
             SemanticGate: vetoes + parts    ▼
                                    JudgementReading ─► UnderstandingJudge (V35 order)
                                                              │
                                    evidence policy (V35) ◄───┘ commit or ask
                                              │
                        learner-model writes: from the lexical diagnosis only
```

* **Stages stay separate.**
  * Language understanding: the lexical reader and the semantic reader.
  * Evidence signals: `ClauseSignal`, `SemanticClauseReading`, `ReasonReading`.
  * Judgement: `UnderstandingJudge`, whose V35 order is unchanged.
  * Learner-model update: `LearnerEvidenceMapper`, which reads the lexical diagnosis.
  * Intervention planning: `InterventionPlanner`.
  * No score collapses them. Every semantic decision lists its reasons: the stand-ins used,
    the opposites found, and the gate's blocks in the order they were checked.
* **What the lexical reader does (unchanged).**
  * It decides coverage, contradictions, reversals, confusions, overgeneralizations and
    verbatim copying.
  * It produces the stored diagnosis, the only source of learner-model writes.
  * With the semantic space removed, V36 reproduces V35 exactly: every metric on all four
    development splits is identical to the pristine V35 checkout.
* **What the semantic reader does.** It reads only clauses the lexical reader left unsettled
  (unsupported, or partial at best). It provides:
  1. **Credit in other words.** It finds the claim the clause fits best: the balance of how
     much of the claim is said, and how much of the clause the claim explains. It then asks
     `SemanticGate` whether the clause says it.
  2. **A reversed sense.** An opposite word, or the opposite polarity on the proposition
     that carries the claim.
  3. **Another concept's wording.** A rival concept explains the clause clearly better.
  4. **An unsupported reason.** The reason after "because", "since", "due to" or similar is
     read, and checked against every claim of the source, in any words.
* **How the judge uses it.** Each item is a hypothesis with a cue. Credit that exists only in
  other words becomes the leading reading, always with a discriminating question. Doubts
  become questions. **Nothing semantic can create or upgrade a write.** The mapper still
  writes from the lexical diagnosis, and every semantic path ends in a question. Credit the
  words already earn is never raised.
* **Vetoes.** Similarity never overrides these; any one blocks semantic credit:
  * a lexical contradiction or proposition conflict;
  * a reversal;
  * a negated claim restated without its negation;
  * an opposite word (WordNet or lexicon poles);
  * opposite polarity on the carried proposition;
  * an unnegated absolute where the source hedges;
  * a subject naming another concept;
  * another concept explaining the clause clearly better.
* **Refusals.** The gate also refuses a clause that:
  * lacks the claim's subject, verb or limiting condition in any words;
  * says too little of the claim;
  * reaches the level on its own words ("ownWords": a level the words already reach was the
    lexical reader's to give);
  * fits two claims about equally.
* **When a reversal counts as a doubt.** Only where both polarities are plain:
  * at most one polarity cue on each side;
  * no negated universal ("not every event");
  * no restrictive the negation restates ("alone … does not" for "only part");
  * the negated words are the claim's own.
* **Where each rule is tested.**
  * `SemanticGateTests` pins the vetoes.
  * `SemanticAdversarialTests` pins the brief's examples:
    * "JWTs are signed so nobody can read them": never credited;
    * "Authentication does not establish identity": never credited.

---

## 10–18. Measurements

### Development splits: V35 → V36 (final code)

| | dev (120, author A) | dev2 (120, authors C, D, E) | legacy-dev (49) | legacy-holdout (43) |
|---|---|---|---|---|
| coarse accuracy | 46% → **47%** | 41% → **44%** | 82% → 82% | 81% → 81% |
| exact state | 23% → 24% | 22% → 25% | 76% → 76% | 72% → 72% |
| false mastery | 0/78 → 0/78 | 4/78 → **3/78** | 0 → 0 | 0 → 0 |
| credited misconceptions | 2 → 2 | 10 → **7** | 0 → 0 | 0 → 0 |
| false misconceptions | 0 → 0 | 3 → 3 | 0 → 0 | 0 → 0 |
| harmful writes | 2 → 2 | 17 → **13** | 0 → 0 | 0 → 0 |
| wrong commits | 12 → 12 | 18 → **13** | 7 → 6 | 4 → 4 |
| misconception caught or probed | 87% → 87% | 69% → 78% | 100% → 100% | 94% → 94% |
| weak reasoning found | 0/12 → 1/12 | 0/12 → 2/12 | – | – |
| probes (asked first) | 97 → 99 | 94 → 99 | 15 → 16 | 11 → 11 |
| Brier | 0.222 → 0.216 | 0.255 → 0.247 | 0.136 → 0.138 | 0.101 → 0.101 |
| ECE | 0.018 → **0.044** | 0.089 → 0.054 | 0.262 → 0.250 | 0.212 → 0.212 |
| rewording invariance | 408 → 408 /422 | 400 → 401 /405 | – | – |
| paraphrase groups, same exact / coarse state | 5 → 5, 13 → 13 /16 | 7 → 6, 12 → 13 /19 | – | – |

The thresholds were calibrated on dev and dev2, so these gains are optimistic. ECE on dev
worsens from 0.018 to 0.044, while Brier improves on both.

### Fresh sealed split (sealed36): V35 → V36

**The split.**
* 160 explanations: 40 from each of four authors, each writing in a different voice:
  * F, a formal non-computing graduate student;
  * G, a terse teenager on a phone;
  * H, a teacher explaining through scenarios;
  * I, a non-technical product manager.
* Seven documents. Mobile Mastery is 39% (the V35 splits were about 90% one book).
* 57 page-level explanations, and 24 paraphrase groups.
* The concepts and passages are disjoint from dev2's (1 shared concept out of 52).
* No author saw Leu's code, the other authors' work or the development splits.

**Scored once**, on the reader with source fingerprint `b6930aac` (see below). Aggregates only.

| | V35 | V36 |
|---|---|---|
| coarse accuracy | 52% | 51% |
| exact state | 29% | 28% |
| **false mastery** | 11/104 | **10/104** |
| mastery recall | 15/56 | 15/56 |
| misconception recall | 8/42 | 8/42 |
| misconception caught or probed | 76% | 79% |
| **credited misconceptions** | 10 | **9** |
| false misconceptions | 4/118 | 4/118 |
| **harmful writes** | 25 | **23** |
| wrong commits | 21 | 20 |
| weak reasoning found | 0/16 | 0/16 |
| probes | 113 (71%) | 114 (71%) |
| Brier / ECE | 0.246 / 0.055 | 0.242 / 0.043 |
| rewording invariance | 518/530 | 518/530 |
| paraphrase groups, same exact / coarse state | 13 / 17 of 24 | 12 / 17 of 24 |

* **By author:**
  * F: safer (false mastery 7 → 6, credited misconceptions 6 → 5, harmful writes 13 → 11).
  * G: identical.
  * H: coarse accuracy one case lower (48% → 45%).
  * I: identical.
* **By category (coarse accuracy):**
  * paraphrase 15/51 → 15/51;
  * novel vocabulary 40/79 → 40/79;
  * example instead of definition 3/9 → 3/9;
  * misconception paraphrase 9/36 → 9/36;
  * negation 14/42 → 14/42 (false mastery 5 → 4);
  * opposite meaning, same words 4/11 → 4/11 (false mastery 4 → 3);
  * verbose with one wrong clause 2/10 → 2/10 (false mastery 2 → 1);
  * subject/object reversal 2/13 → 2/13 (false mastery 4 → 4);
  * right conclusion, wrong reasoning 14/16 coarse, 0/16 exact, both versions.

**Order of events, stated plainly:**

1. Thresholds were calibrated on dev and dev2 and frozen. Then the four sealed annotators
   were started.
2. While they wrote, the adversarial suite (my own sentences, no sealed data) exposed a false
   reversal: "no more than once" was read through "repeatedly". It was fixed, and the dev
   metrics were re-verified. Only three dev2 numbers moved: targeted probes 14 → 13, and
   Brier and ECE by −0.001 each.
3. The sealed split was merged without printing a case and scored once. Headline numbers
   were recorded before any sealed case was looked at. The source fingerprint at scoring
   was `b6930aacda697b09`.
4. **After scoring**, the full suite showed one regression in an existing V34 test.
   * The test: a correct foreign-key explanation was asked "how does it differ from a
     primary key?" instead of being told which idea it missed.
   * The fix restores the lexical reader's own rule: a clause that the target's own words
     explain well is never suspected of confusion. A companion own-share condition went into
     the rival veto.
   * Neither change was informed by sealed data. Neither changes any dev, dev2, legacy or
     Teach It Back number.
   * The vector cache was capped and four helpers were moved out of the diagnoser; neither
     changes behaviour.
5. To keep "score once" strict, the sealed aggregates were **not** printed again. The
   committed suite still evaluates sealed36 on every run, asserting only that V36 is no less
   safe than V35 there (it passes).

### Items 12–18 in brief

* **Paraphrase accuracy (12).**
  * dev: 6/39 → 7/39.
  * dev2: 3/38 → 5/38.
  * sealed: 15/51 → 15/51.
* **Novel-vocabulary accuracy (13).**
  * dev: 31/92 → 32/92.
  * dev2: 17/57 → 20/57.
  * sealed: 40/79 → 40/79.
* **Weak reasoning (14).** Exact detection is 0/12 → 1/12 on dev, 0/12 → 2/12 on dev2 and
  0/16 → 0/16 on sealed. Precision on development data is roughly half: V36 predicts it 3
  times on each split.
  * The unsupported-reason reading reads the words after a reason marker and checks them
    against every source claim in any words. When the reason is unsupported, V36 asks for it
    instead of crediting the conclusion.
  * On sealed, reasons hide behind misspelled markers ("becuase") and fronted clauses
    ("since X, Y"), which this reading misses (§25).
* **False mastery (15).** It never increases: dev 0 → 0, dev2 4 → 3, sealed 11 → 10.
* **Harmful writes (16).** They never increase: dev 2 → 2, dev2 17 → 13, sealed 25 → 23.
* **Calibration (17).**
  * Brier improves on dev, dev2 and sealed. It moves 0.136 → 0.138 on legacy-dev.
  * ECE improves on dev2 and sealed, and worsens on dev (0.018 → 0.044).
  * Semantic-only readings carry confidence 0.5; on development data they were right 3
    times in 6.
* **Probing rate (18).** 81% → 83% on dev, 78% → 83% on dev2, 71% → 71% on sealed.

---

## 19. Teach It Back

* **Nothing was added to Teach It Back.** It compares an explanation with the card's
  paragraph through `UnderstandingDiagnoser()`, so V36 reaches it unchanged.
* **Measured through that exact path.** The concept's card paragraph is the target, every
  development explanation is compared, words only against V36.

| | dev (103) | dev2 (37) | sealed36 (69) |
|---|---|---|---|
| coarse | 43% → 45% | 14% → 14% | 33% → 33% |
| exact state | 19% → 23% | 11% → 11% | 14% → 14% |
| credited misconceptions | 2 → 1 | 6 → 4 | 4 → 4 |
| harmful writes | 2 → 1 | 8 → 6 | 9 → 9 |
| wrong commits | 10 → 9 | 8 → 6 | 11 → 11 |
| weak reasoning found | 0 → 2 /12 | 0 → 0 /1 | 0 → 0 /2 |
| probes | 86 → 89 | 28 → 30 | 49 → 49 |
| Brier | 0.227 → 0.225 | 0.248 → 0.234 | 0.243 → 0.241 |

* **A right explanation in other words is read for what it says.** Example (pinned in
  `TeachItBackSemanticTests`):
  > "Authorization is deciding what a logged-in person is permitted to do, like letting
  > everyone read reports but only admins delete accounts."
  * V35 finds nothing comparable.
  * V36 reads it as mostly understood, asks one question and records nothing yet.
* **A fluent answer with a reason the source does not give is asked about instead of partly
  credited.** Example:
  > "An index makes lookups on a column quicker, because the database remembers the answers
  > of earlier queries…"
  * V36 asks for the mechanism.
  * The next study session asks that question.
* **Not every change helps.** A correct "scaling out… instead of upgrading the one box you
  have" is now asked to contrast horizontal with vertical scaling. That is a false doubt,
  though it records nothing.
* **Absolute accuracy is low for dev2.** The annotators labelled against the concept rubric,
  while Teach It Back compares against a card paragraph. Only the V35-to-V36 difference is
  meaningful there.

---

## 20. Performance

Release builds of pristine V35 and of V36, run alternately twice each on this 4-core Linux
container, with the same timing program.

| | V35 | V36 |
|---|---|---|
| first diagnosis in a fresh process | 53–76 ms | 179–182 ms |
| diagnose + judge, warm (182 explanations × 5): mean | 60–61 ms | 63 ms |
| median / p95 | 65 / 101 ms | 66–68 / 104–106 ms |
| plan a 30-minute session over the 345-page manual | 488 / 525 ms | 522 / 443 ms (noise) |
| resident memory after the first diagnosis | 31.5 MB | 44.7 MB |
| resident memory after 910 diagnoses | 31.7 MB | 53.8 MB |

* **One-time cost: about +110 ms on the first comparison.**
  * Reading the 8 MB space takes 6 ms and parsing it 37 ms.
  * The antonym table and first vector look-ups account for the rest.
* **Steady-state cost: about +3 ms (~4%) per explanation.**
  * A warm word similarity takes 0.31 µs.
  * An uncached word vector (WordPiece and sum) takes 11 µs.
* **Memory: about +13 MB resident for the space and antonyms.**
  * The word-vector cache adds at most about 9 MB. It is capped at 8,192 vectors.
  * Only immutable word vectors are cached, since the same word always gives the same vector.
* **Planning is unchanged.** It never runs the semantic reader.
* **No asynchronous machinery was added.** Loading is lazy on first use. If the first Teach
  It Back comparison ever runs on the main thread, the one-time cost could show as a small
  hitch; warming the space in the background at launch is possible but was not done.
* **Not measured:** on-device timings on iPhone, and memory pressure behaviour.

---

## 21–24. Tests, build, persistence

* **Tests added (21).** 19 tests in 5 files:
  * `SemanticSpaceTests` (4):
    * the bundled file's digest;
    * WordPiece pieces matching the model's own tokenizer;
    * integer similarities pinned to the build, to 1e-12;
    * opposites never counting as paraphrases.
  * `SemanticGateTests` (5):
    * each veto holds even at recall ≥ 0.5;
    * credit rests on the stand-ins;
    * an opposite word the words-only reader credits in part becomes a reversed sense;
    * reversals are read only on the claim's own words;
    * a known phrase-level paraphrase stays uncredited.
  * `SemanticAdversarialTests` (6):
    * 28 new sentences across all 15 categories of the brief;
    * meaning never adds a write that the words-only reader does not make;
    * wrong answers are never credited without their misconception;
    * right answers are never recorded as misconceptions;
    * three known failures are named in the test (§25);
    * the brief's own examples;
    * what V36 adds over words only.
  * `SemanticGeneralizationTests` (2):
    * dev and dev2, V35 against V36: V36 is no less safe, no less accurate, and finds no less
      weak reasoning;
    * sealed36 safety relations, with aggregates printed only on request.
  * `TeachItBackSemanticTests` (2).
* **No test was weakened or removed.** The V35 generalization tests still compare V35 with
  V34. `v35` is now the words-only reader, which is exactly V35.
* **Totals (22).** 475 tests, 0 failures (§27). One V34 test failed on the first full run;
  it was fixed in the reader, not the test (§11).
* **Build, validator and warnings (23).**
  * The clean build (from empty `.build`) has 0 warnings.
  * `scripts/validate.py` passes: 575 source and script files, largest 299 lines. Deep
    Xcode-project parsing is skipped because the Linux `plutil` cannot read the ASCII
    `.pbxproj`; pristine V35 behaves the same.
  * `check-learning-offline` passes, as does `check-worldclass-offline` ("no embedding API,
    no vector database").
  * `check-learning-architecture` flags four app UI files, all unchanged since V35. V35
    flagged five: the diagnoser, the fifth, is now under the 250-line boundary.
  * `check-shelfcore-imports` output is identical to V35's: three app files, none touched.
  * The app-level compile harness builds (§27).
* **Persistence impact (24): none.**
  * No stored type, field or enum case changed. The new cues, hypotheses and reading types
    are transient and not `Codable`.
  * Stored diagnoses are still the lexical ones. A stored follow-up question may now be one
    V36 chose, and its message may use the new weak-reasoning wording. Both go in fields V35
    already writes.
  * V35 and V36 read each other's data. No migration.

---

## 25. Remaining semantic failure categories

From the sealed split, inspected only after its headline numbers were recorded, and from the
adversarial suite. These are identical in V35 and V36 unless noted.

1. **Phrase-level paraphrase.** Static word vectors do not carry it:
   * "remembers its surrounding bindings" against "access to the lexical variables"
     (bindings/variables cosine 0.09);
   * "a brief lifespan limits the harm";
   * "any copy of the server can answer the following call".

   Sealed paraphrase accuracy is unchanged at 29%. The brief's closure pair does **not**
   align in V36. The first sentence is asked about and never marked wrong; the second is
   credited on its words.
2. **Misspellings.** "seperate", "becuase", "enviroment" and "continous" defeat both the
   lexical match and the WordPiece vectors. One sealed false mastery rests on "doesnt keep
   them seperate".
3. **Absolutes outside the lexicon.** "Necessarily" and "invariably" over hedged claims are
   missed. A paraphrase group of three sealed false masteries rests on "a linear scan
   necessarily examines every single element". The semantic gate refuses credit for
   absolutes, but raises no doubt.
4. **Role and direction reversals with the same words.**
   * "the workflow builds the implementation and passes it up to the composition root";
   * "trades read performance for simpler writes";
   * "the outer function keeps access to the inner function's variables".

   Word-level evidence cannot see who does what to whom.
5. **Cause turned into correlation.** "What one observes is a correlation" is still credited.
6. **Reasons.** Fronted reason clauses ("since X, Y") and misspelled markers hide the reason.
   Sealed weak reasoning is 0/16.
7. **False doubts from rival concepts that share vocabulary** (V36 only). Horizontal and
   vertical scaling, and a stateless server against horizontal scaling, produce questions
   on correct answers. They record nothing.
8. **Generic short answers.** One generic four-word answer received semantic credit on
   sealed ("Talk through your thinking." read as mostly understood). It was asked about,
   not recorded.
9. **Known adversarial failures named in the tests** (V35 and V36 alike):
   * "Authorization is what an allowed identity uses to decide who it is" is credited in full.
   * A day-and-night correlation about retries is credited in part.
   * A correct debounce/throttle contrast is recorded as a confusion.

---

## 26. The single highest-value V37 opportunity

**Phrase-level, contextual semantic evidence behind the same gate.** Paraphrase and novel
vocabulary are the largest error categories on sealed (29% and 51% coarse accuracy). The
word-level space demonstrably cannot close them. Contextual token alignment was the best
method in this cycle's spike (AUC 0.805 / 0.918 against 0.786 / 0.854).

The concrete first step:

1. Run `scripts/v36-natural-language-probe.swift` on a Mac and an iPhone.
2. If `NLContextualEmbedding` separates the adversarial pairs, supply its token vectors to
   ShelfCore as an optional evidence provider, injected by the app. That keeps ShelfCore
   dependency-free and its tests deterministic, using recorded vectors.
3. Run it through the existing `SemanticGate`, vetoes and ask-first policy.
4. Measure it on dev2 and on a new sealed split.

Spelling normalization (item 2 of §25) is the cheap companion step.

---

## 27. Final validation

Run on the final sources of this branch (Linux, Swift 6.1.3, debug unless stated):

* **ShelfCore full suite: 475 tests, 0 failures** (827 s).
  * After that run, one unused computed property (`SemanticClauseReading.rivalLeads`) was
    deleted.
  * The package was rebuilt and 79 tests re-run: every semantic, Teach It Back, judge and
    generalization test, including both sealed-split checks. 0 failures.
* **Clean build from empty `.build`: 0 warnings.**
* **App-level compile harness** (ShelfCore plus the app's learning model code,
  `-strict-concurrency=complete`): builds, 0 warnings.
* **Validator** (`scripts/validate.py`): PASS.
* **Offline contracts** (`check-learning-offline.py`, `check-worldclass-offline.py`): PASS.
* **Semantic adversarial suite:** `SemanticAdversarialTests` (28 sentences, 15 categories)
  and `SemanticGateTests`, all passing.
* **Fresh sealed evaluation:** scored once (§10–18). The suite asserts on every run that
  V36 is no less safe than V35 there.
* **Not run:** Xcode build, iOS/macOS unit and UI tests, on-device performance, and the
  NaturalLanguage probe. All need Apple hardware.
