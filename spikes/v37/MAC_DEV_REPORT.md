# V37 — Mac development report (real Apple Foundation Models inference)

2026-09-29 · MacBook Pro Mac15,3 · macOS 26.6 (25G72) · Xcode 26.6 · Swift 6.3.3 · model: `SystemLanguageModel.default`
Open sets only (P, 80 answers; C, the 5 canonical answers). No blind set was inspected, decrypted,
generated or run. Evidence: `dev-log/01.md`–`12.md`, `readings/`, `scores/`.

## Verdict

**Not an architecture failure, and not yet ready for the blind holdout by the owner's own bar.** The
frozen configuration reads learner explanations far better than V36 (74.6% vs 46.2% coarse on P, stable
across four runs, canonical 5/5 on all six real-model runs), but on P it still misses three pre-registered
hard gates on its worst run (G8, G9 by one answer each; G14) and two of the pre-holdout targets (commit
accuracy 88% vs 90%, novel vocabulary 68% vs 70%). See "Readiness" below.

## The frozen configuration (D, dev12)

1. **Row reading** (one call): per segment polarity, role, relation (wire words correct · vague · mistaken ·
   unrelated → entails · partiallyEntails · contradicts · unrelated), claim, likely mistake, target /
   neighbour / unclear, specificity, confidence.
2. **Whole-answer check** (independent call, no reading shown): correct · vague · mistaken · flawedReason.
3. **Locator** (only when the check finds the answer wrong): the false segment or none, what the source
   says instead, the likely mistake, kind (recorded, not trusted), and the claim; the claim is checked
   against the locator's own "instead". Its placement is merged into the recorded reading (raw rows kept).
4. **Deterministic verification and composition:** V1–V11; reason → conclusion links fixed by the
   answer's discourse markers; claim families; premise of a wrong conclusion withheld; D's agreement rules
   (firm only when the independent check agrees; disputed credit partial; unplaced errors asked).
5. **Unchanged V35/V36 judge, planner and evidence mapper**; the adapter records on claim families and
   caps mastery when the essential idea is not fully covered; a wrong reason is always probed.
6. **Misconception memory** in the spike write path (decisive writes only).

Calls run in sequence (parallel calls contend for the on-device model).

## Results on P (D, four real-model runs of the frozen configuration)

| Metric | Runs 1–4 | Mean | Development target | Pre-registered gate |
|---|---|---|---|---|
| Coarse | 73.8 · 75.0 · 75.0 · 73.8% | 74.4% | ≥ 72–75% ✓ | G1 ≥ 70% ✓ |
| Exact state | 39/80 · 41/80 · 39/80 · 39/80 | 49.4% | | |
| Paraphrase | 72.0% each | 72.0% | ≥ 70% ✓ | G2 ≥ 65% ✓ |
| Novel vocabulary | 67.9% each | 67.9% | ≥ 70% ✗ | G3 ≥ 65% ✓ |
| Weak-reasoning recall | 55.0% each | 55.0% | ≥ 55–60% ✓ (floor) | G4 ≥ 45% ✓ |
| Weak-reasoning precision | 64.7–68.8% | 67.4% | ≥ 65% ✓ | G5 ≥ 60% ✓ |
| Mastery recall | 13/22 each | 59.1% | | |
| Misconception recorded | 16–17/28 | 59.5% | | |
| Misconception recorded or probed | 25/28 | 89% | | |
| Commit accuracy | 87.9–88.2% | 88.1% | ≥ 90% ✗ | G6 ≥ 85% ✓ |
| Follow-up rate | 57.5–58.8% | 58.1% | | G7 ≤ 60% ✓ (thin) |
| False mastery | 2, 2, 3, 3 of 58 | 4.3% | extremely low ✗ | G8 ≤ A's 2/58: ✗ worst run |
| Harmful writes | 4, 4, 5, 5 of 80 | 5.6% | | G9 ≤ 0.6 × A's 8/80 = 4.8: ✗ worst run |
| Schema errors / refusals / timeouts | 0 / 0 / 0 (runs 1–3); 1 schema error in run 4 | | | G11–G13 ✓ |
| Run-to-run consistency | 76/80 identical signatures over runs 1–3 (95.0%); coarse class 97.5% | | stable ✓ (coarse) | G14 ≥ 97% ✗ |

V36 (A) on P: coarse 46.2%, commit accuracy 43.5%, false mastery 2/58, harmful writes 8/80.

## Canonical C1–C5 (real model output only; six runs of the frozen configuration)

| Case | Result in 6/6 runs | Behaviour |
|---|---|---|
| C1 | PASS | definition entailed, mostly understood, credit, no question (6/6 identical) |
| C2 | PASS | contradicts the definition, negated; misconception committed in 4 runs, asked as a misconception check in 2 |
| C3 | PASS | definition entailed, mostly understood, credit, no question (6/6 identical) |
| C4 | PASS | conclusion credited, copying reason located and linked by "because": weak reasoning, no mastery, mechanism probe on Closure's definition family (6/6 identical) |
| C5 | PASS | "JWTs are signed" / "so nobody can read them": premise withheld, conclusion located against "not automatically encrypted" with the key mistake "JWTs are always encrypted"; no credit, asked as a misconception check (6/6 identical) |

C5 is asked, not committed, on real output: V9 finds no shared word between "so nobody can read them" and
either the claim or the key mistake, so the wrong idea is doubtful until the learner answers.

## Latency (Mac; the iPhone run comes after the freeze)

* Light background load (three runs): warm p50 **4.0 s**, p95 **7.2 s**, one outlier 17.2 s; cold ≤ 4.3 s.
* Under Apple Intelligence background work (`textunderstandingd`, `mediaanalysisd`, `mobileassetd` active,
  dev08–10): warm p95 12.3–17.3 s, cold up to 11.9 s. A single check call measured 0.5 s before and after.
* Hard ceilings (cold ≤ 20 s, warm ≤ 12 s): met under light load, **not guaranteed under background load**.
  Premium target (p50 ≤ 4 s, p95 ≤ 5–6 s): p50 met at the limit, p95 missed.

## The four architecture risks

1. **Claim selection brittleness — resolved.** Claim families from each claim's concept and role (a
   supporting claim joins the core claim it shares most content with, else the definition); credit and
   coverage are recorded on the family's core claim, and V3–V6 are verified against the named claim and
   its family's core claim. C3 read against "retain access" gets the same judgement as the definition
   (tested for every configuration; every supporting claim in P joins a core claim of its own concept).
2. **Partial entailment — resolved.** Partial is never firm credit (V11); credit the independent check
   disputes is partial at most, one idea at most; mastery needs the definition's family fully covered.
   Full → understood; essential idea covered, the rest omitted → mostly understood (partial but
   meaningful); essential idea partial or only secondary ideas → fragile; nothing → insufficient.
3. **True premise for a false conclusion — resolved.** Reason and conclusion markers (because, since, due
   to, so, therefore, "therefore means", thus, hence, consequently, which means, that's why, as a result)
   split and link segments by direction; a credited premise of a wrong conclusion earns nothing. Tested
   with every marker; on real output C5's premise earns no credit in 6/6 runs.
4. **Misconception memory — implemented, decisive writes only.** Concept, exact claim (core or
   supporting) and its family, the misconception (key mistake or the learner's words), confidence,
   evidence, detection time and version, repair state (open · probed · repaired) and reconfirmations
   (still held · corrected); Codable across sessions; transfer targets per concept. Tested end to end with
   a committed C5. On real output C5 is asked first, so it is written only once confirmed.

## Readiness

Met: coarse, paraphrase, weak-reasoning recall and precision, canonical 5/5 on every run, coarse stable
across runs, no schema/refusal/timeout failures, the 65% stop cleared by ~9 points.
Missed on P: commit accuracy 88% (target 90%), novel vocabulary 68% (target 70%), false mastery 3/58 on
the worst run (G8 asks ≤ A's 2/58), harmful writes 5/80 on the worst run (G9 asks ≤ 4.8), signature
consistency 95% (G14 asks ≥ 97%; greedy decoding is not deterministic on this runtime), and latency is
load-dependent. Spending the holdout now would most likely fail G8, G9 or G14 on its worst run.
