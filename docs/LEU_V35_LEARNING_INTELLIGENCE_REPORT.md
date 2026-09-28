# Leu V35 — Learning Intelligence: Diagnosis Generalization

Branch `claude/leu-v35-diagnosis-generalization`, one local commit on top of the verified V34
baseline `3fbd9aba10b17d9223d262ef313378f80a24caa0`. Not merged, not pushed.

This report states what was measured before anything changed, what was built, and what the
measurements do and do not show. Every number below comes from a test run on this branch or
on a pristine checkout of the baseline. Numbers that were not measured are marked as such.

---

## 1. Summary

**The question V35 set out to answer.** V34 scored 74% on its held-out diagnosis split, but
only after fixes that the blind run (56%) had exposed. Does Leu's judgement of learner
understanding hold up on explanations nobody tuned it for? And can it recognize when it
does not know, instead of writing a guess into the learner model?

**What the evidence says.**

* **The lexical reader does not generalize, and V35 did not fix that.** On 240 new
  explanations written by two separate annotators, V34 gets the coarse reading
  (understands / weak / misconception) right on **46%** (dev) and **45%** (sealed).
  V35 gets **46%** and **44%**. Most of these answers use words the source does not use
  (77% of dev cases), and word overlap cannot read them. This is the central limitation,
  and V35 does not claim to have fixed it.
* **What V35 does change is what Leu writes into the learner model.** A new transient
  judgement layer weighs the readings an answer allows. It commits only when the evidence
  supports one reading clearly. Otherwise it asks one discriminating question and records
  nothing until the answer comes. On the sealed split, which was evaluated once after
  implementation was frozen:
  * wrong verdicts written to the learner model fell from **23 → 12**;
  * harmful ones (crediting a wrong idea, a false misconception, or a missed misconception)
    fell from **8 → 5**;
  * false mastery fell from **1/78 → 0/78**, and credited misconceptions from **2 → 0**;
  * every gold misconception is now either recorded or asked about (**94% → 100%**);
  * confidence is calibrated: Brier **0.550 → 0.245**, ECE **0.550 → 0.058**.
* **The costs are real.**
  * Leu now asks before learning on **81%** of answers (V34: 66%).
  * It credits real understanding immediately less often: mastery recall **12% → 7%**.
  * It records one fewer true misconception on sealed (**4 → 3** of 31).
  * It raises one more committed false alarm (**4 → 5**).
  * Learner-state trajectories are not measurably more stable.
  * The weak-reasoning state exists but does not work yet: it identifies **0 of 12** dev
    cases.
* **Teach It Back is now first-class evidence** through the existing interaction model.
  * An explanation is read against the learner's live misconceptions.
  * An undecided explanation teaches the model nothing yet. Its question becomes the first
    recall activity of the next study session.
  * An understood explanation is followed by one transfer question, where the concept
    has one.
* **No schema change, no new stored state, no visual change, no new dependency.** All V35
  state is either transient or derived from what V34 already stores.
* **An independent adversarial review** of the finished diff found three major problems and
  eight minor ones (§16). All three major ones and five of the minor ones were fixed before
  the commit; the rest are listed.

The honest one-line verdict: **V35 makes Leu safer and better calibrated about what it
does not understand. It does not make Leu understand more.** §18 names the change that
would.

---

## 2. Method and discipline

1. **Baseline preserved first.** Before any change, the V34 suite ran (424 tests, 0
   failures), and every V34 diagnosis on the V34 fixture was dumped case by case. A
   pristine git worktree at `3fbd9ab` was kept for the whole cycle, so every "V34" number
   here is V34's own code, measured with the same harness as V35.
2. **Audit before architecture.** Every held-out failure was traced to a cause (§3). The
   lexicon was ablated to measure lexical overfitting.
3. **New evaluation data before implementation.** Two annotator agents wrote and labeled
   the explanations. Each worked only from a written labeling guide
   (`Tests/Fixtures/diagnosis-generalization-guide.md`) and a catalog of the source
   sentences for its split's concepts. Both were instructed not to read Leu's code,
   lexicon, tests or any other fixture.
   * **dev** (120 cases, author A) was used for development and calibration.
   * **sealed** (120 cases, author B) was never opened by the implementer. It was scored
     once for V35, after implementation was frozen. Only aggregates were ever printed.
     V34's sealed aggregates were measured before implementation, as the baseline.
   * The test suite also runs the sealed split on every run, for relative safety
     assertions that print nothing.
4. **Labels were never changed.** This holds for the V34 fixture and both new splits.
5. **The V34 held-out split is contaminated.** It was read during the audit, so its
   numbers are a regression view, not evidence of generalization.
6. **Separating the two layers.** The harness also runs "V35 reader + V34 policy": V35's
   diagnosis with V34's rule of recording whatever the diagnosis shows. This isolates what
   the reader fixes did from what the judgement did.

**Fixture composition (dev; sealed follows the same guide).**

* Gold states: 24 understood, 18 mostly understood, 18 fragile, 30 misconception,
  12 weak reasoning, 18 insufficient.
* 31 cases carry a gold misconception (one weak-reasoning case also states a wrong
  reason); 6 carry two.
* Categories: novel vocabulary 92, paraphrase 39, partially correct 19, confidently wrong
  17, hedged 17, novel example 12, right conclusion with wrong reasoning 12, terse 11,
  irrelevant but plausible 8, verbose 8, multiple misconceptions 6, near-verbatim 4.
* 16 paraphrase groups (sealed: 14).
* 12 page cases; 108 of 120 cases come from the 345-page Mobile Mastery manual.

**Metrics** (`Tests/ShelfCoreTests/V35/GeneralizationEvaluation.swift`):

* **coarse** — the reading (positive / weak / misconception) matches gold.
* **false mastery** — a `.correct` observation recorded for an answer whose gold state is
  not understood or mostly understood.
* **mastery recall** — the same, for answers that deserve it.
* **misconception recall** — the gold misconception is recorded as a misconception.
* **caught or probed** — it is recorded, or asked about before anything is recorded.
* **misconception credited** — it is neither, and credit is recorded.
* **false misconception** — a misconception is recorded where gold has none.
* **probes** — the answer records nothing until a question is answered.
* **selective accuracy** — coarse accuracy over committed answers only.
* **wrong commits** — committed answers read wrong. They are split into over-credit,
  false alarm, missed misconception, and under-credit. The first three are the harmful
  kinds.
* **targeted probes** — probes on misconceptions that ask about the misread claim or the
  confused concept.
* **Brier and ECE** — calibration of the stated confidence of the coarse reading. V34
  states no confidence and writes every verdict into the model, so it is scored at 1.
* **paraphrase stability** — every member of a group gets the same state (exact) or the
  same reading (coarse).
* **metamorphic invariance** — the same outcome after four meaning-preserving rewrites
  ("I think …", "Basically, …", an appended "That's how I understand it.", contractions
  expanded).
* **trajectories** — explanations replayed day by day through the real reducer.
  * **recovery** — a recorded misconception, then two corrected explanations on later
    days.
  * **recency** — understood, then a misconception: the model must end at misconception.
  * **stability** — paraphrases on consecutive days must not flip the state. Flips are
    counted from the second answer on, so a two-member group cannot flip; the stable
    counts are an upper bound, and "flips" is the informative number.

---

## 3. Failure taxonomy of the original 74% held-out result

The baseline reproduces V34's numbers case by case: dev 45/49 (92%), held-out 32/43 (74%,
non-blind; V34's only blind held-out run scored 56%). Each of the 11 held-out failures was
traced by reading its per-clause alignment features.

| Case | Primary cause | Also involved | What happens |
|---|---|---|---|
| ho-hash-01 | evaluator underspecification | — | the learner's second claim is partially credited correctly; the labels omit it, so it counts as a false alignment |
| ho-cors-02 | evaluator underspecification | multiple misconceptions | Leu contradicts exactly the supporting claim the answer denies; the scorer checks a different label field than the one the case's intent requires |
| ho-jwt-02 | evaluator underspecification | multiple misconceptions | same scorer rule; the second wrong idea ("nobody can read the payload") is read as partially supporting |
| ho-authz-02 | lexical overfitting (overlap read as meaning) | calibration, insufficient evidence | "Once you know who the user is, they have permission to do everything" is credited as covering "Identity alone is not permission": the negation is lost across the leading clause |
| ho-authz-01 | lexical overfitting (paraphrase missed) | — | "knowing who someone is does not mean they have permission" fails the subject gate |
| ho-ci-01 | lexical overfitting (discourse paraphrase missed) | — | the clause split loses "otherwise"; the idea goes uncredited and is flagged unsupported |
| ho-authn-02 | ambiguous concepts | lexical (family bleed via "check"), calibration | authorization's definition is given for authentication and partially credited, just under the rival threshold |
| ho-thr-02 | ambiguous concepts | evaluator (the contradiction found is also true) | debouncing's idea is given for throttling; the contradiction is found but the confusion misses its margin |
| ho-idem-02 | insufficient evidence, committed anyway | calibration | "can only be performed once" is partially credited on one shared word, "once" |
| ho-retry-02 | partial understanding (over-alignment) | evaluator | the overgeneralization is found, but two partial credits, one on a single word, count as false alignments |
| ho-cs-01 | knowledge extraction (outside diagnosis) | — | the contradicted claim begins with "It"; V34 removed pronoun resolution, so the claim cannot be represented |

**Counts by primary cause (11 failures):**

* evaluator underspecification 3 (27%);
* lexical overfitting 3 (27%);
* ambiguous concepts 2 (18%);
* insufficient evidence committed 1 (9%);
* partial understanding 1 (9%);
* knowledge extraction 1 (9%).

The other categories in the brief have no primary failures:

* **Multiple misconceptions** — involved in 2 cases, primary in none. The design reports
  one wrong idea per clause.
* **Right answer from incorrect reasoning** — the V34 fixture has no such case, so it
  could not be measured. The new splits have 12 per split.
* **Stale learner state** — none. The V34 benchmark is stateless.
* **Calibration** — every V34 verdict is committed without uncertainty. All three
  failures that credited a wrong idea (authz-02, idem-02, authn-02) rested on thin
  lexical credit. On held-out, thin credit (best recall < .5, or at most 2 matched words)
  was wrong 3/5 times, against 4/20 for strong credit. On dev it was wrong 1/14 times:
  that threshold had been tuned there.

**Real system errors: 7 of 11.** The rest are 3 evaluator issues and 1 extraction gap. The
costliest class, crediting a wrong idea, is 3 of 11. Counting the 3 label omissions as
passes, held-out would be 35/43 (81%). That figure is adjudicated and is not a headline.

**How much of 74% was lexical overfitting.** Measured on a scratch copy of the lexicon:

* Removing all synonym families: dev 92 → 76%, held-out 74 → 65%.
* Removing everything: dev 61%, held-out 44%.
* Leave-one-out over 181 entries: one missing entry flips 11/45 dev passes and 10/32
  held-out passes.
* Eight phrase entries match only held-out learner texts and never occur in the corpus
  ("takes load off", "roll back", "around the world", …). Removing them leaves dev
  unchanged at 45/49 and drops held-out from 32 to 30.
* **So at least 2 held-out passes (4.7 points) came from vocabulary fitted to the
  held-out texts.**

V35 added **no lexicon entries**.

---

## 4. Architecture

```
learner answer
  │  UnderstandingDiagnoser — lexical reader (V34) + three general fixes (§4.2)
  ▼
UnderstandingDiagnosis (stored, V34 shape) ─┐
DiagnosisSignals (transient, per clause)  ──┤  recall, distinctive words, rival concept share,
                                            │  conflict overlap, unexpressed negation
                                            ▼
                         JudgementReading → hypotheses (reading · support · cue · claim)
                                            ▼
                         UnderstandingJudge — ordered, deterministic decision boundary
                                            ▼
          UnderstandingJudgement { state · confidence · hypotheses · question? }   (never stored)
             │                                         │
   question == nil                             question != nil ("needs evidence")
             ▼                                         ▼
   LearnerEvidenceMapper → evidence          nothing recorded; InterventionPlanner words the
   (weak reasoning capped at partial)        discriminating question from templates; it is
             ▼                               stored as the diagnosis's follow-up (V34 field)
   LearnerModelReducer (V34, unchanged)                ▼
                              TeachBackFollowThrough.pending — derived from stored attempts
                                                       ▼
                              ShelfStudySessionPlanner → AdaptiveProbeSelector (step 2b)
```

### 4.1 New modules (all deterministic; no wording decides anything)

* **`Judgement/UnderstandingJudgement.swift`** — the transient types:
  * `UnderstandingState`: understood, mostly understood, fragile, misconception, weak
    reasoning, insufficient evidence;
  * `UnderstandingHypothesis`: a reading, its support, the cue behind it, a claim, and a
    related concept;
  * `DiscriminatingQuestion`: the readings it separates, its claims, the operation, and a
    related concept;
  * `UnderstandingJudgement`, `UnderstandingAssessment`, and `LearnerPrior` (the salient,
    still-active misconceptions for the answer's concepts).
* **`Judgement/JudgementReading.swift`** — reads the hypotheses from the diagnosis and its
  signals:
  * how clearly each stated wrong idea is stated;
  * possible confusions (another concept's grounded wording explains a clause clearly
    better than the target's);
  * omitted negations;
  * self-doubt ("not sure", "maybe", a trailing "?"; "kind of" but not "a kind of");
  * earlier misconceptions about an assessed claim that this answer does not clearly
    correct;
  * the strength of credit (strong / moderate / thin, from recall and distinctive-word
    counts);
  * a reason the source does not settle, offered for a right conclusion.
* **`Judgement/UnderstandingJudge.swift`** — the decision boundary, in order:
  1. nothing comparable → insufficient, ask for the idea itself;
  2. a clearly stated wrong idea → misconception, recorded now;
  3. a doubtful wrong idea, a possible confusion, an omitted negation, or a live earlier
     misconception → ask the question that separates misconception from credit;
  4. copied wording, thin credit, or a learner who says they are unsure → ask before
     crediting;
  5. otherwise the diagnosis stands, except that a right conclusion with an unsettled
     reason is weak reasoning.

  Confidences are histogram-calibrated on dev. They are named constants with their
  derivation documented in the code.
* **`Diagnosis/DiagnosisSignals.swift`** — per-clause evidence strength, collected while
  the diagnoser runs.
* **`Memory/LearnerModel/LearnerConceptState.swift`** — the per-concept state. It is a
  function of stored evidence and the date: mastered, mostly understood, fragile,
  misconception, weak reasoning, insufficient evidence, unknown.
* **`TeachLeu/TeachBackFollowThrough.swift`** — pending verifications, derived from
  stored attempts, the learner model and the current analyses.

### 4.2 Reader fixes (general rules, not vocabulary)

* **Unexpressed negation.** A clause can restate a negative claim's content while saying
  nothing negative. That means no negation, no "without", no negative verb or its
  paraphrase family, and no flipped pole. Such a clause no longer credits the claim. The
  judge weighs it as a possible misreading.
* **Rejected alternatives.** "Unlike a hash, …" and "instead of a listener on every
  child" name what the learner contrasts, not what they assert. These spans are removed
  from the clause's propositions, from subject matching, and from the overgeneralization
  test.
* **Overgeneralization scope.** A universal counts only when it is not negated ("not every
  event") and only when it quantifies what the source qualifies. "Shown on every API
  call" beside "usually short-lived" no longer counts.

### 4.3 Changed modules

| File | Change |
|---|---|
| `UnderstandingDiagnoser.swift` | `assess(_:target:prior:)` returns diagnosis + judgement + signals; `diagnose` is unchanged for callers |
| `InterventionPlanner.swift` | when the judgement needs evidence, the next step is its discriminating question (contrast, misconception check, or the claim in its own terms), worded from templates. Three cases keep V34's next step: "nothing comparable" is the leading reading, the wording was copied, or the diagnosis states a wrong idea |
| `LearnerEvidenceMapper.swift` | `evidence(from: UnderstandingAssessment)`: no evidence while undecided or insufficient; weak reasoning capped at partial; typed recall the judgement can't confirm counts only as the learner's own rating, with "Knew it" read as "Difficult" |
| `TeachBack.swift` | `assessment(_:source:knowledge:model:at:)` reads the explanation against the learner model; `assess` is unchanged |
| `AdaptiveProbeSelector.swift` | step 2b, after live misconceptions: a pending discriminating question becomes a validated open probe; a pending transfer check picks a level ≥ 3 probe |
| `StudySessionPlanner.swift` | concepts with a pending verification get learner priority ≥ 0.7; a pending discriminating question makes its passage's recall activity come first |
| App: `ReaderIntelligenceModel.swift`, `LearningModel+Adaptive.swift`, `LearningModel.swift` | Teach It Back and typed recall use the assessment; the assessment is held in an `@ObservationIgnored` property, never stored |

The largest new source file is 149 lines, and no coordinator class was added. The judge
never raises credit above what the diagnosis found. It only decides how far that finding
can be trusted.

---

## 5. Results — dev split (120 cases; development and calibration data)

| Metric | V34 | V35 reader + V34 policy | **V35** |
|---|---|---|---|
| coarse reading right | 46% | 46% | **46%** |
| exact state right | 21% | 21% | 23% |
| false mastery | 0/78 | 0/78 | **0/78** |
| mastery recall | 7/42 (17%) | 8/42 (19%) | 6/42 (14%) |
| misconception recorded | 3/31 | 1/31 | 1/31 |
| misconception caught or probed | 87% | 84% | 87% |
| misconception credited | 4 | 5 | **2** |
| false misconception | 3/89 | 0/89 | **0/89** |
| answers that wait for a question | 82 (68%) | 83 (69%) | 97 (81%) |
| committed / selective accuracy | 38 / 39% | 37 / 41% | 23 / **48%** |
| wrong commits (over · false alarm · missed · under) | 23 (2·0·6·15) | 22 (2·0·5·15) | **12 (1·0·2·9)** |
| targeted probes on misconceptions | 16/24 | 18/25 | 19/26 |
| Brier / ECE | 0.542 / 0.542 | 0.542 / 0.542 | **0.222 / 0.018** |
| paraphrase groups stable: exact / coarse | 7/16 · 13/16 | 7/16 · 13/16 | 5/16 · 13/16 |
| metamorphic invariance | 406/422 | 408/422 | 408/422 |
| trajectories: recovery · recency · stable · flips | 0/1 · 4/26 · 12/14 · 2 | 0/0 · 1/26 · 12/14 · 2 | 0/0 · 1/26 · 13/14 · 1 |

The calibration numbers on dev are in-sample, because the confidences were fitted here.

**Why V35 records fewer misconceptions on dev (3 → 1).** Both lost recordings come from
the overgeneralization-scope fix. V34 flagged five dev answers as overgeneralizations.

* Three were correct answers, and V35 no longer flags them: gd-008 ("not every event"),
  gd-067 ("every API call") and gd-094.
* The other two were wrong answers flagged for the wrong reason: gd-080 is a
  contradiction and gd-095 a confusion. V35 asks about both instead.

The same shift explains recency falling from 4/26 to 1/26: fewer misconceptions are
recorded outright, so fewer "understood, then wrong" sequences end at misconception.

---

## 6. Results — sealed split (120 cases; scored once, aggregates only)

| Metric | V34 | V35 reader + V34 policy | **V35** |
|---|---|---|---|
| coarse reading right | 45% | 45% | 44% |
| exact state right | 25% | 25% | 27% |
| false mastery | 1/78 | 1/78 | **0/78** |
| mastery recall | 5/42 (12%) | 5/42 (12%) | 3/42 (7%) |
| misconception recorded | 4/31 | 3/31 | 3/31 |
| misconception caught or probed | 94% | 90% | **100%** |
| misconception credited | 2 | 3 | **0** |
| false misconception | 6/89 | 5/89 | 5/89 |
| answers that wait for a question | 79 (66%) | 79 (66%) | 97 (81%) |
| committed / selective accuracy | 41 / 44% | 41 / 44% | 23 / 48% |
| wrong commits (over · false alarm · missed · under) | 23 (1·4·3·15) | 23 (1·4·3·15) | **12 (0·5·0·7)** |
| targeted probes on misconceptions | 19/25 | 19/25 | 20/28 |
| Brier / ECE | 0.550 / 0.550 | 0.550 / 0.550 | **0.245 / 0.058** |
| paraphrase groups stable: exact / coarse | 2/14 · 9/14 | 2/14 · 9/14 | 3/14 · 10/14 |
| metamorphic invariance | 397/414 | 397/414 | 405/414 |
| trajectories: recovery · recency · stable · flips | 0/0 · 4/18 · 11/12 · 1 | 0/0 · 3/18 · 11/12 · 1 | 0/0 · 3/18 · 10/12 · 2 |

**How to read these numbers.**

* **The sample is small.** A difference of one or two cases (false mastery 1 → 0, false
  misconception 6 → 5, selective accuracy 44 → 48%) is within noise. The changes large
  relative to the sample:
  * wrong commits roughly halved (23 → 12);
  * no credited or missed misconception (5 → 0 combined);
  * calibration: V35's stated confidence transfers to data it was not fitted on. ECE on
    sealed is 0.058, against 0.018 on dev.
* **The calibration gain is partly by construction.** V34 states no uncertainty at all.
  The part that is not automatic is that V35's confidences hold on unseen data.
* **Accuracy did not improve.** Coarse accuracy is flat, and mastery recall fell.
* **The reader fixes cost one true misconception recording on sealed (4 → 3).** They
  removed one false one.
* **The judgement adds one committed false alarm.** Its clear-misconception rule commits
  some verdicts that V34's level mapping had left weak.

**The sealed figures are for the code as frozen at evaluation.** The review fixes that
followed (§16) did not change a single judgement or evidence metric on dev or on the V34
fixture. On dev, one more probe now targets the confused concept. Two of those fixes could
still move sealed results, and they were not re-scored, to keep the split single-use:

* the self-doubt rule, which could affect single answers containing "a kind of" with
  credit;
* the fallback and lingering rules, which could affect targeted probes and trajectories.

---

## 7. The V34 benchmark, as a regression check

**Old actionable metric (labels untouched).**

* Dev: 45/49 (92%) → **45/49 (92%)**.
* Held-out: 32/43 (74%, non-blind) → **32/43 (74%)**.
* Claim alignment, issue recall and false-issue counts are identical: dev 41/45 · 27/28 ·
  2; held-out 37/41 · 17/22 · 3.
* **Only ho-authz-02 changed.** V35 no longer credits "they have permission to do
  everything" as covering "Identity alone is not permission"; it asks about that claim.
  The benchmark still counts the case as a failure, because its labels expect a stated
  contradiction.
* **All three held-out answers that V34 credited with a wrong idea are now asked about:**
  * ho-authz-02 — the misread claim;
  * ho-idem-02 — "what is idempotency?";
  * ho-authn-02 — "How does authentication differ from authorization?".
* **ho-jwt-02 is shown but not recorded.** Its thinly supported contradiction is still
  shown beside the source sentence, as in V34. It is not recorded as a misconception;
  the answer to the follow-up decides what is recorded.

**The V34 fixture read as judgements** (coarse labels derived mechanically from the V34
labels; the held-out split is contaminated by the audit):

| | V34 | **V35** |
|---|---|---|
| dev: coarse · false mastery · credited misconceptions · wrong commits (harmful) | 76% · 0/32 · 0 · 11 (3) | **82% · 0/32 · 0 · 7 (0)** |
| held-out: coarse · false mastery · credited misconceptions · wrong commits (harmful) | 81% · 1/22 · 2 · 7 (3) | **81% · 0/22 · 0 · 4 (0)** |
| held-out mastery recall | 18/21 | 17/21 |
| probes dev / held-out | 20% / 19% | 31% / 26% |

On this fixture V35 is under-confident: ECE is 0.26 on dev and 0.21 on held-out. The
confidences were fitted where the reader is weak, and this fixture's vocabulary is the one
V34 was tuned on.

---

## 8. False mastery

False mastery was treated as the most expensive error. V35 never raises credit above what
the diagnosis found. Its whole policy moves in one direction: from committing to asking.

| | V34 | V35 |
|---|---|---|
| false mastery — dev | 0/78 | 0/78 |
| false mastery — sealed | 1/78 | **0/78** |
| false mastery — V34 fixture dev / held-out | 0/32 · 1/22 | 0/32 · **0/22** |
| any credit for a gold misconception — dev / sealed | 4 · 2 | **2 · 0** |
| over-credit among committed verdicts — dev / sealed | 2 · 1 | **1 · 0** |

**What still slips through on dev.** Two misconceptions get partial credit, never mastery:

* **gd-024** gives authentication's definition for authorization. "Checking" matches
  authorization's own wording, and the rival's grounded wording lacks "username" and
  "password", so no confusion is suspected.
* **gd-065** says vertical scaling has "no ceiling", a contradiction in words the reader
  does not know.

The one over-credit is gd-084: a right conclusion with a wrong purpose, credited as mostly
understood with partial evidence. Its reason is not marked by "because" or "since", so the
weak-reasoning check does not fire.

**The mechanisms:**

* A negated claim is never credited without its negation.
* Credit resting on one distinctive word or thin recall is asked about first.
* So is credit from a learner who says they are unsure.
* A live misconception is not papered over by an ambiguous answer.
* A right conclusion with an unsettled reason earns partial credit at most.
* A doubt question asked with no misconception on record is recorded at its claim's own
  level, never as connect-level evidence.
* Typed recall the judgement cannot confirm downgrades "Knew it" to "Difficult".

---

## 9. Paraphrase, generalization and robustness

* **Coarse accuracy by category on dev (V35).**
  * Strong: irrelevant but plausible 8/8, terse 10/11, partially correct 17/19,
    hedged 14/17, right conclusion with wrong reasoning 10/12.
  * Weak: paraphrase 6/39, novel vocabulary 31/92, novel example 3/12, confidently wrong
    2/17, multiple misconceptions 1/6.
  * The weak categories are exactly where meaning is carried by words the source does not
    use.
  * The "right conclusion, wrong reasoning" score is coarse: those answers are read as not
    yet understood. The weak-reasoning state itself is identified in 0 of 12, and once on
    an understood answer.
* **By gold state (dev, V35).**
  * Fragile 17/18 and insufficient 18/18 are right, but all 36 were asked about.
  * Understood 5/24 and mostly understood 2/18 are right, and 27 of those 42 were asked
    about.
  * Misconception: 3/30 are read as misconceptions, and 25 of 30 are asked about.
* **Metamorphic rewrites.** Invariance rose on sealed (397 → 405 of 414) and held at
  408/422 on dev. The remaining variance is mostly lexical: a prefix changes a clause's
  subject reading.
* **Paraphrase groups.** Coarse stability is unchanged on dev (13/16) and 9 → 10 of 14 on
  sealed. Exact-state stability fell on dev (7 → 5 of 16) and rose on sealed (2 → 3 of
  14). With six states instead of five, the thin-versus-strong credit boundary can split
  paraphrases that V34 treated alike.
* **Novel vocabulary and analogies remain unread.** The judgement cannot see meaning that
  the reader does not see. It only avoids pretending to.

---

## 10. Adaptive probing

**The decision boundary** is §4.1, and it is deterministic: the same answer, source and
learner model always give the same judgement (tested). **What gets asked:**

| Leading doubt | Question (existing operation) | Next-step message (existing slot) |
|---|---|---|
| another concept's wording | contrast the two concepts | "Your explanation could also describe X." |
| a wrong idea stated on thin evidence | misconception check on that claim | V34's: the learner's words beside the source sentence. It is not recorded until answered |
| omitted negation | the claim, in its own terms | "Leu can't tell yet how you read one part of your source." |
| a live earlier misconception not clearly corrected | misconception check on that claim | same |
| thin partial credit | the credited claim, in its own terms | same |
| thin full credit, or a learner who says they are unsure | the credited claim, in its own terms | "You may have this already, but Leu can't tell from these words yet." |
| copied wording | purpose / own words | V34's |
| nothing comparable | define | V34's |

The messages state the doubt and never promise a question: the recall card shows the
message without its question, while Teach It Back shows the question below it. Nothing is
revealed that V34 would not reveal. Question wording comes from the existing templates;
FoundationModels is not involved.

**Measured.**

| | dev: V34 → V35 | sealed: V34 → V35 |
|---|---|---|
| answers held for a question | 68% → 81% | 66% → 81% |
| committed verdicts | 38 → 23 | 41 → 23 |
| selective accuracy | 39% → 48% | 44% → 48% |
| gold misconceptions caught or probed | 87% → 87% | 94% → 100% |
| probes on misconceptions aimed at the misread claim or confused concept | 16/24 → 19/26 | 19/25 → 20/28 |

Targeting did not improve on sealed: 76% vs 71%.

**The follow-through is exercised by scripted tests, not measured statistically.** The
fixtures have gold labels for single answers only. There is no gold answer to the
follow-up question, and recovery sequences had no eligible cases in the new splits.

---

## 11. Teach It Back as first-class evidence

* **The same screen and the same result.** `TeachLeuResult` and its V27/V34 backend
  string are unchanged, so stored attempts keep the V34 shape. No view file changed. The
  approved design is untouched; only the text of the existing "next step" line differs
  for undecided answers.
* **Read against the learner.** Teach It Back passes the learner model's live, salient
  misconceptions for the passage's concepts. An answer that neither restates nor clearly
  corrects a live misconception is asked about. It cannot erase the misconception.
* **Evidence only when decided.** An undecided explanation is stored with no evidence
  (`evidenceRecordedAt` stays nil). The existing repository rule then counts the first
  decided revision of that attempt exactly once. Weak reasoning records at most partial
  success.
* **Follow-through without new state.** `TeachBackFollowThrough` derives pending work
  from attempts stored in the last 14 days whose passage is unchanged:
  * **discriminate** — the attempt taught nothing and its diagnosis carries the question.
    It clears as soon as the concept is answered in any way.
  * **transfer** — the explanation was understood. The next session asks one contrast or
    example question where the concept has one. Any later answer settles it, and mastery
    still requires success at the connect or transfer level.
* **The next study session asks first.** The concept's learner priority rises to at
  least 0.7. A pending question makes its passage's recall activity rank first, and the
  selector turns the stored question into an open probe that passes `ProbeValidator`.
* **Typed recall.** In study sessions, typed recall is judged in the same way.

**Limitations.**

* A pending question is asked only if its concept's passage is a study object in the
  session plan. Concepts outside the plan (for example, the Idempotency page of the
  manual) keep the question on the Teach It Back screen only.
* Recall answers leave no pending question behind.

---

## 12. Tests

**32 new tests in 4 classes, plus the evaluation harness** (3 support files), in
`Tests/ShelfCoreTests/V35/`:

* **`UnderstandingJudgeTests` (16)**:
  * clear paraphrases are credited without a question;
  * universals count only where the source is qualified;
  * rejected alternatives are not read as claims;
  * negated claims are never credited without the negation, and the omission is asked in
    the claim's own terms;
  * a thinly supported contradiction is shown beside the source but not recorded;
  * thin credit, self-doubt (but not "a kind of"), rival-concept wording (even with
    nothing else credited) and copied wording are asked about first;
  * answers the target explains well are not suspected of confusion;
  * weak reasoning earns partial credit only;
  * nothing comparable learns nothing;
  * clear wrong ideas are recorded at once;
  * live misconceptions are asked about until clearly corrected, while one on a
    supporting claim holds nothing back;
  * unconfirmable typed recall downgrades "Knew it";
  * determinism.
* **`TeachItBackLoopTests` (7)**:
  * an undecided explanation teaches nothing, is followed up with its own question (never
    from a changed page), and the session asks it first;
  * an understood explanation gets one transfer check, which any later answer settles;
  * a misconception is retired only by clear corrections on two days, while a vague
    answer changes nothing;
  * contradicting evidence outweighs earlier understanding;
  * a deferred attempt is stored, and re-read, in the V34 shape;
  * paraphrases don't flip the state.
* **`LearnerConceptStateTests` (5)**:
  * unknown and insufficient evidence;
  * mostly understood until connected or transferred;
  * mastery fades with no stored label;
  * a live misconception wins, and a resolving one is fragile;
  * weak reasoning.
* **`GeneralizationEvaluationTests` (4)**:
  * the dev report, with guards: V35 must not have more false mastery, credited
    misconceptions or false misconceptions than the V34 policy, must have fewer harmful
    commits and a lower Brier score, and must still credit at least half the
    understanding the V34 policy credits;
  * the V34 fixture read as judgements, with the same guards;
  * the sealed split: the relative safety guards on every run, printing nothing unless
    `LEU_SEALED_REPORT=1`;
  * the metrics themselves, on hand-built predictors.

No existing test was modified or removed.

**Suite.** The entire suite ran from the clean build (§13): **456 tests, 0 failures**.
That is the 424 V34 tests, all still passing, plus the 32 new ones. The sealed guard ran
and printed nothing. Wall time was 8 min 49 s.

---

## 13. Validation

* **Repository validator** (`scripts/validate.py`): **PASS**, exit 0.
  * 560 source/script files, the largest 299 lines (an existing file).
  * The plist/JSON/XML, local-package and native-membership checks pass.
  * Deep Xcode project parsing is skipped, as the validator reports, because `plutil` is
    not available on Linux.
* **Clean build from an empty build directory:** `swift build --build-tests` into a fresh
  scratch directory **succeeded** in 43 s (debug, tests included).
* **Warnings:** **0** compiler warnings in the clean build of ShelfCore and its tests,
  and 0 in the strict-concurrency app harness.
* **App code.** It cannot be compiled on Linux (SwiftUI, PDFKit, FoundationModels).
  * The three changed app files pass `swiftc -parse`.
  * The changed model logic (`LearningModel+Adaptive.swift`, byte-identical copy) compiles
    against ShelfCore with `-strict-concurrency=complete` in a harness with a stubbed
    `LearningModel`. So does a line-for-line mirror of the new Teach It Back block in
    `ReaderIntelligenceModel`. Both have 0 warnings.
  * An Apple toolchain build and on-device run were **not** performed here.

---

## 14. Performance

Release builds (`-c release`) of pristine V34 and V35 were run alternately on this 4-core
Linux container, twice each, with the same timing file.

| | V34 (round 1 / 2) | V35 (round 1 / 2) |
|---|---|---|
| diagnose one explanation: mean (212 explanations × 5 passes) | 69.3 / 75.7 ms | 72.4 / 72.2 ms |
| median | 77.8 / 82.6 ms | 80.0 / 79.0 ms |
| p95 | 119.2 / 137.3 ms | 128.9 / 132.2 ms |
| plan a 30-minute session over the 345-page manual: mean of 5 | 660 / 803 ms | 646 / 593 ms |

* **No measurable latency change.** V34's two rounds differ more (69 vs 76 ms) than V34
  and V35 do. For V35, `diagnose` includes the judgement and the per-clause rival scan.
* **Planning is unchanged.** With no attempts to follow up, the new step scans an empty
  list; it is bounded by the 14-day window.
* **Timing predates the review fixes.** Those add no per-explanation work, apart from one
  precompiled regular expression that replaces thirteen compiled per call.
* **Not measured:** on-device timings, and planning with many pending attempts.

---

## 15. Persistence and schema

**No stored type, field or enum case was added or changed**, so V34 and V35 read each
other's data.

* Every new public type is transient, or derived on demand from what V34 already stores.
* `ProbeReason` gained `.verification`. That enum lives only in `ProbeDecision`, which is
  never encoded; activities store the probe itself.
* Stored diagnoses may now carry a discriminating question in the existing `followUp`
  field. Its message uses an existing `InterventionKind`.

**Where the transient/persisted boundary sits, and why.**

* **The judgement is not stored.** It is a function of the answer, the source and the
  learner model at that moment. Storing it would freeze a reading that later evidence
  should be free to revise. It would also require new cases in V34's persisted diagnosis
  enums, which V34 cannot decode.
* **The per-concept state is not stored.** It is derived from per-operation evidence
  weights, spaced successes, misconception records and the date. So it follows
  forgetting and fading misconceptions without migrations. A stored label would
  duplicate that evidence and drift from it.
* **Pending verifications are not stored.** They follow from facts V34 already stores:
  an attempt that recorded no evidence, the question its diagnosis carries, and when the
  concept was last seen.
* **What is stored** is what the judgement lets through — existing `LearningEvidence`
  and existing `UnderstandingAttempt`s.

Because every capability could be built on the existing model, the constraint was never
invoked ("if persisted state must change, stop and document why").

---

## 16. Independent review

After the sealed evaluation, a separate agent reviewed the finished diff adversarially. It
worked read-only, did not compile, and did not open the sealed split. It reported three
major findings and eight minor ones. Persistence, concurrency and test integrity were
checked clean. Each finding was verified against the code before acting on it.

| Finding | Disposition |
|---|---|
| **Major:** a transfer check could never clear for a concept without a contrast or example question, so the planner promoted it for 14 days | **Fixed:** any later answer about the concept settles it |
| **Major:** recall cards show the next-step message without its question, and the messages promised "one more answer" that never came | **Fixed:** messages state only the doubt |
| **Major:** an overgeneralization recorded on a supporting claim, which no answer's evidence carries, held back every typed answer on the concept for about five weeks | **Fixed:** lingering doubts consider only claims an answer can speak to |
| A doubt with nothing else credited lost its discriminating question (it fell back to "what is X?") | **Fixed:** V34's next step is used only when "nothing comparable" leads |
| Doubt questions used the misconception-check operation (level 3) with no misconception on record, so a plain restatement could count as connect-level evidence | **Fixed:** the claim's own operation unless a misconception is on record |
| Follow-ups could be worded from a page that has since changed | **Fixed:** only attempts whose passage is unchanged are followed up |
| "a kind of", "what kind of" counted as self-doubt | **Fixed** |
| The safety guard would pass for a predictor that asks about everything | **Fixed:** dev and V34-fixture guards also require half the V34 policy's mastery credit |
| A misleading test comment; `LearnerPrior`'s documentation said "unresolved" where the code keeps active records | **Fixed** (comments only) |
| Follow-ups are keyed on the draft's creation time, so a draft resumed days later can lose its follow-up | **Not fixed** (§17) |
| "This thought is settled" drops the follow-up | **Kept:** it is the learner's explicit choice |
| Rating a recall card before its assessment arrives keeps full "Knew it" credit | **Not fixed:** V34 had the same race (§17) |
| Two-member paraphrase groups cannot flip under the stability metric | **Documented** (§2) |

**One problem found by the implementer during the final checks.** A thinly supported
contradiction produced both a "CHECK THIS" beside the source sentence and a "Leu can't
tell yet" next step.

* **Fix:** a wrong idea the diagnosis states keeps V34's next step, and the judgement only
  withholds recording it.
* **Scope:** none of 153 real Teach It Back comparisons from the dev and V34 fixtures
  reached this path.

**Test coverage of the fixes.** Every behavioural fix is pinned by a test. Three of them —
the stated-contradiction rule, the supporting-claim rule and the self-doubt rule — were
confirmed to fail with the fix reverted.

---

## 17. Known weaknesses

1. **The reader is lexical.** It cannot read novel vocabulary, analogies or examples that
   the source does not use. Coarse accuracy on independent text is about 45%, and mastery
   recall is 7–14%. V35 is honest about this; it does not fix it.
2. **Leu asks a lot.** 81% of answers wait for a question: mostly "nothing comparable"
   (which V34 already deferred), plus about 13 points of new doubt questions. A learner
   who understands but writes in their own words will often be asked again before
   getting credit.
3. **Weak reasoning is not detected.** It fires only when an unsupported clause carries a
   reason marker ("because", "since"): 0 of 12 on dev, plus one false positive.
4. **Misconception recording is low.** 1–3 of 31 are recorded outright; most are asked
   about instead. The reader fixes cost one true detection on sealed (4 → 3).
5. **Committed false alarms on sealed rose by one (4 → 5).** False misconceptions are
   essentially unchanged there (6 → 5).
6. **Heuristic cues.** Self-doubt markers and keyword-list detection can still misfire.
   Synonym-family bleed between neighbouring concepts ("check" in both verify and decide)
   still causes spurious rivals and missed confusions (gd-024).
7. **The follow-through has gaps.**
   * A pending question reaches the study session only if its passage is in the plan.
   * Recall answers leave no follow-up.
   * Follow-ups are keyed on the draft's creation time, so a draft resumed after other
     answers on the concept, or after 14 days, loses its follow-up.
8. **A rating race predates V35.** A recall rating given before the background assessment
   finishes is recorded as V34 would record it.
9. **Trajectory metrics are weak.** Recovery had no eligible sequence; recency and
   stability did not improve. The single-answer fixtures cannot measure the value of the
   follow-up loop. That needs gold second answers.
10. **Calibration is dataset-dependent.** It is well calibrated on the new splits and
    under-confident on the V34 fixture.
11. **Author and document skew.** The splits have one author each, and 90% of cases come
    from one document.

---

## 18. The single highest-value V36 opportunity

**Give the judge a semantic reader.** Add an on-device meaning-similarity signal between
each learner clause and each grounded claim, for example the NaturalLanguage framework's
sentence embeddings, verified to work offline on the target devices. It would sit beside
the lexical alignment in `ClauseSignal`. The V35 judge, its decision boundary, the lexical
polarity and negation checks (which embeddings are known to miss) and the evidence policy
stay as they are.

* Recalibrate the confidences on dev.
* Evaluate once on a fresh sealed split written like these.
* Success criteria: coarse accuracy and mastery recall rise, false mastery stays at zero,
  and the ask rate falls.

Every V35 measurement points at the same bottleneck. The judgement now knows when the
reader has not understood; the reader must understand more. This needs an Apple
toolchain, because NaturalLanguage is not available on Linux. It costs nothing at runtime
and keeps Leu offline.
