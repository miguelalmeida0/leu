# Leu V37 capability spike — preregistration

**Registered and approved:** 2026-09-29, and binding from that date. It changes only through
a dated entry in `DEVIATIONS.md` that you have approved. G16 was added at approval, before
any case was written. The method is in [SPIKE_SPEC.md](SPIKE_SPEC.md); on any decision rule, this
document wins.

## 1. Hypothesis

H1: the frozen primary configuration (§2) meets **every** hard gate in §5 on the fresh primary
gate. If it does not, the Apple system-model architecture has failed this spike.

## 2. Primary configuration

**D.** The Apple system model produces a structured reading; deterministic checks
(V1–V9, or the subset kept during development) are applied; a differently worded second
opinion follows; then the unchanged V35 judge, planner and evidence mapper decide.

The primary becomes E (D plus an NLI veto) only through the pre-freeze rule in §7, and the
choice is recorded in the freeze manifest.

## 3. Data

* **Primary gate PG — RETIRED from the pass/fail role (amendment A1).** The final gate is the new
  holdout NH ([HOLDOUT_PLAN.md](HOLDOUT_PLAN.md)). PG as sealed: 240 cases, 6 new authors (J–O) × 40,
  as specified in SPIKE_SPEC §3.3.
  Blind after structural validation. 25% double-labelled; raw coarse agreement ≥ 80% before
  scoring (guide repair as in SPIKE_SPEC §3.3).
  * **Sealed 2026-09-29** (`gate/FINGERPRINTS.txt`) with `openssl enc -aes-256-cbc -pbkdf2
    -iter 200000 -salt`. The passphrase is held by the owner and never committed. Decrypting
    needs OpenSSL ≥ 1.1.1 (for example Homebrew `openssl@3`); macOS's bundled LibreSSL may not
    support `-pbkdf2`.
  * **Passphrase rotated 2026-09-29**, because the first passphrase was exposed in the
    conversation. All three files were re-encrypted in memory under a new random passphrase,
    and every round trip was verified against the recorded plaintext hashes before the old
    ciphertexts were replaced. **The plaintext is byte-identical** (same SHA-256 values below).
    The old passphrase no longer opens the current files. The new passphrase is held by the
    owner only: never printed, committed or logged.
  * `primary-gate.json.enc`:
    * plaintext SHA-256 `c1c1b53088ed8bd8291535283df8d1e49a96ddcb1f31a47c36e5188af8730ada`
    * ciphertext SHA-256 `413990bdb05106b39ee355822fce3f9c59dea0d04f9387314dd444d687a570b5`
  * `labels2.json.enc` (the blind second labels):
    * plaintext SHA-256 `8ed9d58e3e97d780a0a541dc4d133f57c9cf668b50236c2774647d6e6c9040d0`
    * ciphertext SHA-256 `5e5a54f7bffe40ef3a4b4b05eb98873a4650fdab3519bb4f7a29c719e87cfd12`
  * `double-label-map.json.enc` (neutral id → case id):
    * plaintext SHA-256 `93a4f4301ecdd9d8900e00232d0f0c4efb8afe32d05a280423c0afc9cb8a9937`
    * ciphertext SHA-256 `f64b12c2b5a4031401b0b475f22604e0f06b469e565618dad6ecdbaefec23735`
  * **Superseded ciphertexts** (the exposed first passphrase opens these) remain in branch
    history at commits `5be790b` and `0f66470`. Purging them needs a rewrite of this throwaway
    branch's history; that is pending the owner's decision.
  * **Agreement** (`gate/AGREEMENT.json`), 60 cases double-labelled (25%, 10 per author):
    * raw coarse agreement **100%** (60/60), coarse κ 1.00;
    * exact-state agreement 98.3% (59/60), exact κ 0.98.
    * Guide repair: not required. Adjudication: not required (0 coarse disagreements).
  * **Gold labels** are the authors' own. No label was changed after structural validation.
* **Development P** (80) and **canonical C** (5) are open. They are the only data used for
  development and failure analysis.
* **sealed36 (S36)** is secondary: totals only, **never part of the decision**. A must
  reproduce the recorded V36 totals (coarse 51%, false mastery 10/104, harmful writes 23,
  probes 114) before any gate run.

## 4. Metric definitions

All metrics come from `GeneralizationEvaluation.evaluate(…, metamorphic: false)` on PG
(`unavailable` must be 0). Terms used below:

* **Gold coarse:** "misconception" if the case lists any misconception or its state is
  misconception; "positive" for understood or mostly understood; "weak" otherwise.
* **Predicted coarse:** taken from the predicted state alone.
* **Signature:** (state, asks a question?, records mastery?, records a misconception?).

| Metric | Definition |
|---|---|
| Coarse accuracy | `coarseRight / cases` |
| Paraphrase | coarse accuracy over cases tagged `paraphrase` |
| Novel vocabulary | coarse accuracy over cases tagged `novelVocabulary` |
| Weak-reasoning recall | `weakReasoningDetected / goldWeakReasoning` (exact state) |
| Weak-reasoning precision | `weakReasoningDetected / predictedWeakReasoning` (0 when nothing is predicted) |
| Commit accuracy | `committedRight / committed`, where committed = cases − probes (0 when nothing is committed) |
| Follow-up rate | `probes / cases` |
| False mastery rate | `falseMastery / goldNotPositive` |
| Harmful-write rate | `(falseMastery + falseMisconception + misconceptionCredited) / cases` |
| Schema-error rate | cases with any decoding, schema or V1-structural failure in any model call / cases |
| Refusal rate | cases with any guardrail violation or refusal / cases |
| Timeout rate | cases with any call over its timeout (reading 30 s, second opinion 15 s) / cases |
| Run-to-run consistency | share of PG cases whose signature is identical across frozen Mac runs 1–3 |
| Mac–iPhone agreement | share of PG cases whose signature is identical on Mac run 1 and the iPhone run |
| iPhone latency (per answer) | wall time on the iPhone 15 Pro from submitting the answer to the decision being ready: the reading call, the second-opinion call, any logged `rateLimited` retries, and the deterministic checks and judge. Only PG answers of **≤ 80 words** (whitespace-separated) count. The once-per-target answer-key compile is excluded; its time is reported separately (§11). |
| Warm latency sample | every ≤ 80-word PG answer in the iPhone run after the first model call of that app process |
| Cold first-answer latency | 20 cold launches: the app is terminated and relaunched (`xcrun devicectl … --terminate-existing`), and each launch times exactly one ≤ 80-word PG answer, chosen in seeded order, with no earlier model call in the process. That launch's per-answer latency is its cold first-answer latency. |
| Cold ceiling statistic | the **slowest** of the 20 cold first-answer latencies (a ceiling: every cold launch counts, none is discarded) |
| p95 | the nearest-rank 95th percentile of a latency sample |

No latency-hiding optimization is allowed in the measured runs: no `prewarm`, no speculative
or background model calls before the answer is submitted, no caching of readings, and no
streaming counted as "done" early.

A case whose model call fails is scored with V35's decision for that case, as the product
would behave. It is also counted in the failure rates above, and it is never dropped.

## 5. Hard gates (primary gate only)

Any miss means the capability spike FAILS.

| # | Gate | Threshold |
|---|---|---|
| G1 | Coarse accuracy | ≥ 70% |
| G2 | Paraphrase | ≥ 65% |
| G3 | Novel vocabulary | ≥ 65% |
| G4 | Weak-reasoning recall, scored apart from the state (A2) | ≥ 45% |
| G5 | Weak-reasoning precision, scored apart from the state (A2) | ≥ 60% |
| G6 | Commit accuracy | ≥ 85% |
| G7 | Follow-up rate | ≤ 60% |
| G8 | False mastery rate | ≤ A's rate on PG |
| G9 | Harmful-write rate | ≤ 0.6 × A's rate on PG |
| G10 | Canonical examples | 5/5, each meeting its SPIKE_SPEC §3.2 criteria, on every required run |
| G11 | Schema-error rate | ≤ 2% |
| G12 | Refusal rate | ≤ 3% |
| G13 | Timeout rate | ≤ 1% |
| G14 | Run-to-run consistency | ≥ 97% |
| G15 | Mac–iPhone agreement | ≥ 95% |
| G16-warm | iPhone 15 Pro warm latency, answers ≤ 80 words | **p95 ≤ 12 s** (hard gate). 6–12 s passes, but must be flagged as a production UX problem. Over 12 s = FAIL. |
| G16-cold | iPhone 15 Pro cold first-answer latency | **≤ 20 s** (hard operational ceiling; the slowest of the 20 cold launches). 12–20 s passes, but requires a production prewarming strategy. Over 20 s = FAIL. |

* **Required runs:** frozen Mac runs 1, 2 and 3, and the iPhone 15 Pro run (with its 20 cold
  launches).
* **How gates apply.** G1–G13 are evaluated on **each** required run, and the worst run
  counts. G14 and G15 are evaluated as defined in §4. **G16-warm and G16-cold are separate
  gates** on the iPhone run. Each must pass on its own. Their samples are never pooled or
  averaged, and a good result on one can never offset a bad result on the other.
* **A0 and A** are deterministic and scored once on PG, at scoring time only.
* **Runs.** Every completed run counts; no completed run may be discarded or repeated. A run
  interrupted by an infrastructure failure (app killed, device restart) is logged and restarted
  from the beginning.
* **Latency.** G16-warm and G16-cold are the only latency gates. G16 was added before any case
  existed and split into warm and cold before any Apple-model inference (both 2026-09-29).

**No reinterpretation.** After scoring, none of the following is allowed:

* redefining a metric;
* excluding a category, case or run;
* relabelling;
* changing a threshold;
* adding a check, rule or word list;
* treating a near miss as a pass.

## 6. Early stops (the gate is not consumed)

* **ES1.** At the end of development (≤ 3 working days or ≤ 25 iterations, whichever comes
  first): if the best Apple configuration (B, C or D) has coarse accuracy **< 65%** on P,
  STOP. The Apple model fails, and the next step is §8.
* **ES2 (freeze precondition).** The final configuration must pass canonical 5/5 on 3
  consecutive development runs; otherwise STOP, and the next step is §8.
* **ES3.** If the gate result looks incremental (coarse accuracy **≤ 62%**, i.e. about
  51% → 55–60%), it is classified as an **architectural failure**. No word rules, no
  threshold rescue, no NLI rescue, no production work. The next step is §8.

## 7. When E (the NLI veto) may be added — before the freeze only

E is added only if all of these hold at the end of development, measured on P:

1. D passes ES1 and ES2.
2. D misses **at most two** of G1–G9 (checked on P against A's P results). Each miss is within
   5 points for a rate, or within 20% relative for G8 and G9.
3. In a deterministic failure analysis on P, **≥ 60%** of D's errors behind the missed gates
   are *relation errors*: the reading chose the claim the gold label refers to, but gave the
   wrong relation (entails, contradicts or unrelated).

If all three hold, then:

* **Build:** `cross-encoder/nli-deberta-v3-base` on the Mac, veto only, with at most one extra
  development day.
* **Adoption:** E becomes the primary only if it fixes at least one missed gate on P, without
  lowering P's coarse accuracy or raising its false mastery.
* **Otherwise D stays primary.**

E is never added after the gate is scored. E0 (NLI-only) is not built.

## 8. If the Apple model fails: fallback ladder

1. **The bundled contextual model.**
   * **Model and runtime:** Qwen3.5-4B Q4_K_M, the checksum from `MODEL_MANIFEST.json` on
     `codex/qwen-local-understanding`, through llama.cpp `4c9233c`, with Metal, on the Mac.
   * **Decoding:** JSON-schema-constrained, temperature 0, fixed seed.
   * **Pipeline:** the same schema, prompts, checks, second opinion and judge path.
   * **Adaptation:** on P only, for at most 1 day or 10 iterations. ES1 and ES2 apply.
   * **Scoring:** frozen, then scored **once** on the still-blind PG against G1–G14. G15 is
     replaced by a device-feasibility study on iPhone 15 Pro (memory, latency, and agreement
     ≥ 95% with the Mac), which must pass before any go.
2. **NLI-only architecture:** not run. It cannot meet G4 and G5 by construction; a
   reduced-scope V37 would be a new decision for you.
3. **Otherwise: NO-GO for free-text intelligence**, reported as such.

## 9. Blindness rules

1. **Gate cases** are never displayed after structural validation. They are encrypted at rest
   and decrypted only on the Mac at the frozen-run step, into a temporary directory outside the
   repository that is deleted after the runs.
2. **Gate and sealed36 output** is printed as aggregates only (report lines, per-category,
   per-state and per-author counts, failure rates). Per-case readings and judgements live only
   in `blind/` directories and are never printed.
3. **Failure analysis** uses P and C only.
4. **After the spike** (including any fallback), opening the gate requires your explicit
   approval.

## 10. Harness-defect rule

After a gate run, only **code** defects may be fixed: runner input/output, parsing, or adapter
mapping. Prompts, checks, thresholds and answer keys may not be changed. A fix is allowed
only if the defect is demonstrated on P, C or synthetic data. After the fix, the gate is
re-scored once, and the change is logged in `DEVIATIONS.md` with before and after aggregates.

## 11. Reported, not decided

* full latency distributions (median, 90th percentile, max; Mac and iPhone), token counts,
  and answer-key compile time on the iPhone for the canonical targets;
* sealed36 totals;
* breakdowns by category, author and state;
* paraphrase-group stability, Brier score and ECE;
* how often each check fires and how often it is right;
* second-opinion agreement;
* answer-key compile failures;
* the number of gate cases affected by the weak-reasoning coarse quirk (SPIKE_SPEC §8).

## 12. Freeze manifest (`FREEZE.txt`, written before any gate run)

The manifest records:

* **The configuration:**
  * the spike branch commit;
  * the primary configuration (D or E);
  * the enabled checks;
  * the SHA-256 of the reading, second-opinion and answer-key prompts, the schema, the
    segmentation rules, the adapter/checks sources and the runner sources;
  * the generation settings;
  * the SHA-256 of the answer keys (compiled after the freeze).
* **The machines:** Mac model and OS build (`sw_vers`), Xcode version, Apple Intelligence
  status; iPhone model and iOS build.
* **The date and time.**
* **The gate fingerprints** from §3.

## 13. Outcomes

* **PASS:** the next step is a proposal only: the large evaluation corpus and the production
  plan. Nothing is implemented without your approval.
* **FAIL:** follow §8.
* **NO-GO:** report the evidence.

## Amendments before case writing

* **2026-09-29 — G16 added.** Your instruction: iPhone 15 Pro latency p95 ≤ 12 s for answers
  ≤ 80 words; cold and warm measured separately; 6–12 s passes but is reported as a production
  UX problem; over 12 s fails. Recorded before any development or gate case was written.
* **2026-09-29 — G16 split into warm and cold**, at your instruction, after Step 1 and **before
  any Apple-model inference**. The worst-of-cold-and-warm rule is replaced:
  * **Warm:** p95 ≤ 12 s for answers ≤ 80 words is a hard gate. 6–12 s passes, but is flagged as
    a production UX problem. Over 12 s fails.
  * **Cold:** first-answer latency ≤ 20 s is a hard operational ceiling, measured as the slowest
    of the 20 cold launches. 12–20 s passes, but requires a production prewarming strategy. Over
    20 s fails.
  * Cold and warm are measured separately and never averaged. Neither can hide the other.
* **2026-09-29 — gate passphrase rotated** after the first passphrase was exposed in the
  conversation. The plaintext is byte-identical; only the ciphertexts changed (§3).

## Amendments before development (2026-09-29, at your instruction)

Recorded before any Apple-model inference and before any development run. They override the
sections they name.

* **A1 — Primary gate replaced (§3, §5).**
  * PG, sealed 2026-09-29, is **retired from the pass/fail role**. Its first passphrase was
    exposed in the conversation, and the ciphertexts that passphrase opens remain in branch
    history. It is never decrypted or scored.
  * The final gate is a **new independent sealed holdout (NH)** of about 240 cases, following
    [HOLDOUT_PLAN.md](HOLDOUT_PLAN.md).
  * NH is written only **after** the complete freeze: prompts, schemas, segmentation, checks,
    adapter, scoring and thresholds.
  * Its passphrase is generated straight into a file and never displayed, committed or logged.
  * No development agent ever sees its plaintext. It is decrypted only for the one frozen gate run,
    and it is run once. Nothing is tuned after its result is seen.
* **A2 — Weak reasoning scored apart from the state (§4, G4, G5).** A case can hold a misconception
  and a reasoning fault at once, and precedence must not hide the fault.
  * **Gold reasoning issue:** NH's explicit `reasoningIssue` label. For P and C, which have no such
    label, a gold reasoning issue is either:
    * the state `weakReasoning`; or
    * the tag `rightConclusionWrongReasoning`, `wrongConclusionPlausibleReason` or
      `causeVsCorrelation`.
  * **Predicted reasoning issue:** either:
    * the judgement is weak reasoning; or
    * in B, C and D, a reason → conclusion link survives the checks, and either its reason earns no
      credit or its conclusion is a wrong idea.
  * **G4** weak-reasoning recall = detected / gold ≥ 45%.
  * **G5** weak-reasoning precision = detected / predicted ≥ 60%.
  * The old exact-state numbers are still reported.
* **A3 — Canonical expectations as you restated them (§3.2, G10).**
  * **C4:** no mastery; weak reasoning; and **the next question targets the access/mechanism claim**
    (`nextQuestionClaimIDsInclude`), whether the judgement commits or asks.
  * **Next-question rule:** when the judgement is weak reasoning and the reading ties the wrong
    reason to a claim, the one next question asks about that claim.
  * This changes which claim is asked about, never what is recorded: the judge and the evidence
    mapper are unchanged.
* **A4 — Confidence in the reading (§5, §7).**
  * Each segment label carries `confidence` (high · medium · low), and V1 validates the value.
  * **V10** (C, D): a label the model calls low-confidence is never written firmly. Credit becomes
    tentative; a wrong idea becomes doubtful.
  * The request layout is now version 2; prompt-set SHA-256
    `0ec5cad0d660258d578d169759ab9bc88fc7d5c2ecf366335b71f9f340afadf1`.
* **A5 — Development budget (§6).**
  * At most 3 working days and 25 meaningful iterations, on P and C only.
  * **ES1:** if the best of B/C/D is below 65% coarse accuracy on P, STOP.
  * **ES2** (canonical 5/5 on three consecutive development runs) is unchanged.
* **A6 — Hard gates, on NH.** G1–G15 as before, with G4 and G5 per A2, and canonical 5/5 on every
  required run.
  * **Latency:** warm p95 ≤ 12 s is a hard gate; cold ≤ 20 s is the operational ceiling. They are
    measured separately and never averaged.
  * The report also gives the distance to a premium 4–5 s warm target.
* **A7 — Stretch targets** (reported only, never used to claim a pass): coarse ≥ 80%,
  paraphrase ≥ 75%, novel vocabulary ≥ 75%, weak-reasoning recall ≥ 65%, commit accuracy ≥ 92%,
  false mastery near zero, consistency ≥ 98%.
* **A8 — On failure.** STOP, with no rescue by special-case lexical rules. The report must give:
  * the exact failure taxonomy, with examples by class (P and C only);
  * which part failed: model, schema, verification, judge or latency;
  * a recommendation for the next architecture, comparing a different Apple-model strategy, a
    compact local NLI verifier, the bundled contextual model (with the Qwen device evidence) and a
    hybrid.
* **A9 — Branches.** The spike continues on `test`. Nothing merges into `dev` before a genuine pass.
* **A10 — Final report.** It covers only: the best development configuration, canonical 5/5, the
  blind gate result, V36 vs V37, latency, the failure taxonomy, GO / ARCHITECTURE FAIL, and the
  exact next engineering step.

## Deviations log

Recorded during the Mac development loop (2026-09-29), before any freeze and before any look at a blind
set. Each was made on P and C only; the evidence is in `dev-log/`.

* **D1 — Harness defect fixed (§10).** Foundation Models rejects an array schema bounded `0…1`, so every
  one-segment reading failed (`ModelManagerError 1032`). `links` is bounded `0…max(k, 2)` (dev01).
* **D2 — The second opinion is redesigned** (§2 "a differently worded second opinion"). The approved
  pairwise prompt answered "opposite" to nearly every pair on the real model (dev01). D's second opinion
  is now a **whole-answer check** (correct · vague · mistaken · flawedReason) and, when it finds the answer
  wrong, a **locator** (segment, what the source says instead, likely mistake, kind, claim; may answer
  "none"). The pairwise prompt is no longer called. A third, differently worded credit check was tried
  and rejected (dev10).
* **D3 — The reading is two model calls.** The row call (relation spelled correct · vague · mistaken ·
  unrelated on the wire, mapped back to the contract; polarity first) and the locator's placement merged
  into the recorded reading; the raw rows are kept in `rows`. Calls run in sequence.
* **D4 — Reason → conclusion links come from the answer's discourse markers** (because · since · due to ·
  so · therefore · thus · hence · consequently · which means · that's why · as a result), exported with
  the input; C and D use only these (the model's own links linked everything to everything).
* **D5 — Checks added** (DEV_LOOP allowed pruning only): V11 (partial entailment is never firm), P1 (a
  premise of a wrong conclusion earns nothing), F1 (claim families), V3–V6 verified against the claim
  family's core claim, and D's agreement rules. At the owner's instruction (risks 1–4, 2026-09-29).
* **D6 — The adapter records credit on claim families and caps the level** when the essential idea (the
  definition's family) is not fully covered. The judge, planner and evidence mapper are unchanged; the
  sealed36 baselines reproduce exactly after every change.
* **D7 — Answer keys:** kind before sentence; a candidate restating a claim is dropped; the self-check is
  the whole-answer check reading the candidate as a student answer (the pairwise check kept 22 true claims
  as "mistakes" on P).
* **D8 — Misconception memory** (`ZZSpikeMemory.swift`) is new, in the spike write path only.

* **D9 — Final narrow pass (dev13–14, reopened at the owner's instruction).** In D, agreement of the
  independent check outranks the lexical checks V3–V7 and the row's self-reported confidence V10 (V2, V9,
  V11 still bind); V3 is split and an omitted negation (V3a) feeds the judge's own omitted-negation rule; a
  reason clause that is unmatched or restates a negated claim is an unsettled reason; outcomes carry
  independent claim, reasoning and misconception facets. An order-consensus link check was tried and
  removed. Thresholds, metrics, gold labels and the scorer's definitions are unchanged (the scorer's per-case
  rows gained reporting-only fields: `credit`, `reasoningFacet`, `misconceptionFacet`).

**Known risks to the gates from development evidence:** greedy decoding is not deterministic on this
runtime (G14), and latency swings 2–3× with Apple Intelligence background work on the same machine (G16).

## Post-freeze record: the NH holdout (appended 2026-09-29; nothing above this line changed)

* **Frozen candidate:** code `28ee88a17caf6dd612e2ff660225da1ce8473ef8`, manifest `6ca336497d851cdad4dadf9f9250fcac3303d7d4`
  (configuration D, dev14; prompt-set `8921d92f…`). Every frozen component hash re-verified at `28ee88a` and at
  the head before authoring (34/34). Commits after the freeze touch only CI, UI tests and production files the
  spike does not call (`DeterministicQuestionEngine+Utilities`, `KnowledgeIndexBuilder`, `SemanticCompiler`);
  none is a frozen component.
* **D10 — Orchestration.** HOLDOUT_PLAN assigns orchestration to the cloud session. At the owner's explicit
  approval, NH was orchestrated from the Mac session instead, so the passphrase file lives on the Mac that runs
  the gate. The orchestrator saw only ids, problem codes and aggregate counts; a content search over its own
  transcript found none of the 507 answer/note markers.
* **Created:** 2026-09-29, authors **Q, R, S, T, U, V** (new agent instances, 40 cases each) and one new blind
  second labeller; targets: seed 3738 (`score/build_nh_catalogs.py`, reproducible byte for byte).
* **Cases:** 240. Aggregates, validation and agreement: `gate-nh/NH_REPORT.md` (validator: problems 0).
* **Double labelling** (60 cases, 10 per author, first round, no guide repair): coarse raw 95.0%, κ 0.925;
  reasoningIssue raw 98.3%, κ 0.964.
* **Sealed files** (`openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -pass file:`; plaintext hash over
  canonical JSON):

  | File | Plaintext SHA-256 | Ciphertext SHA-256 |
  |---|---|---|
  | `gate-nh/nh-holdout.json.enc` | `ed3f8e1fa355fc4cccd2f9a35013103e40d36a8ec9984cef984e1501e92dba83` | `f8e97affe3b9837848ba67f4edeead112a6a23f691d48bc5d32c0c23d1a04e79` |
  | `gate-nh/nh-labels2.json.enc` | `d215a002b3f2f658f20850a3356feb3b4ef3a087b8f10935205bc057338d283c` | `d474883a50d3aca7303ff2dd60252f28a929eaf1e357975f77f6338447c255e1` |
  | `gate-nh/nh-double-label-map.json.enc` | `c02352a5df2882ac8a3c1f037331f187b31345db71bfef920cfd646c9e86335d` | `903ad809d982428604026f2fb65cb7eecee219b6bbdea633fb15fce061b50ef4` |

* **Passphrase file (path only):** `~/.leu-v37-nh-passphrase` on the owner's Mac, mode 0600, generated by
  `openssl rand` straight into the file; never displayed, logged or committed.
* **Plaintext destroyed and verified:** the work and kit folders, the seven agent transcripts and one stray
  helper copy deleted; afterwards, 0 marker hits and 0 SHA-256 matches (13 plaintext hashes, 71,889 files)
  across the repository, temp directories, `~/.claude`, `~/Documents`, `~/Desktop` and `~/Downloads`.
* **Caveat:** authors and second labeller are instances of one model family; agreement measures consistency
  under the guide, not independent human judgement.
