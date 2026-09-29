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

* **Primary gate PG.** 240 cases: 6 new authors (J–O) × 40, as specified in SPIKE_SPEC §3.3.
  Blind after structural validation. 25% double-labelled; raw coarse agreement ≥ 80% before
  scoring (guide repair as in SPIKE_SPEC §3.3).
  * **Sealed 2026-09-29** (`gate/FINGERPRINTS.txt`) with `openssl enc -aes-256-cbc -pbkdf2
    -iter 200000 -salt`. The passphrase is held by the owner and never committed. Decrypting
    needs OpenSSL ≥ 1.1.1 (for example Homebrew `openssl@3`); macOS's bundled LibreSSL may not
    support `-pbkdf2`.
  * `primary-gate.json.enc`:
    * plaintext SHA-256 `c1c1b53088ed8bd8291535283df8d1e49a96ddcb1f31a47c36e5188af8730ada`
    * ciphertext SHA-256 `ebded0d0fb1687aec4caa28c5cb1c51e1895649e17ddbf5932923462a53e9327`
  * `labels2.json.enc` (the blind second labels):
    * plaintext SHA-256 `8ed9d58e3e97d780a0a541dc4d133f57c9cf668b50236c2774647d6e6c9040d0`
    * ciphertext SHA-256 `e3e405ecfd23ae1d998faf201140144535eb2f02b76138e83143d9079755d714`
  * `double-label-map.json.enc` (neutral id → case id):
    * plaintext SHA-256 `93a4f4301ecdd9d8900e00232d0f0c4efb8afe32d05a280423c0afc9cb8a9937`
    * ciphertext SHA-256 `900fc8169ef7a1039df94ae9f3867181c2a410af134fbba8fe3fbe3b1bdacd98`
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
| Cold latency sample | 20 cold launches: the app is terminated and relaunched (`xcrun devicectl … --terminate-existing`), and each launch times exactly one ≤ 80-word PG answer, chosen in seeded order, with no earlier model call in the process |
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
| G4 | Weak-reasoning recall | ≥ 45% |
| G5 | Weak-reasoning precision | ≥ 60% |
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
| G16 | iPhone 15 Pro latency, answers ≤ 80 words | p95 ≤ 12 s for the **warm** sample **and** for the **cold** sample. 6–12 s passes, but must be reported as a production UX problem. Over 12 s = FAIL. |

* **Required runs:** frozen Mac runs 1, 2 and 3, and the iPhone 15 Pro run (with its 20 cold
  launches).
* **How gates apply.** G1–G13 are evaluated on **each** required run, and the worst run
  counts. G14 and G15 are evaluated as defined in §4. G16 is evaluated on the iPhone run, cold
  and warm separately, and the worse of the two counts.
* **A0 and A** are deterministic and scored once on PG, at scoring time only.
* **Runs.** Every completed run counts; no completed run may be discarded or repeated. A run
  interrupted by an infrastructure failure (app killed, device restart) is logged and restarted
  from the beginning.
* **Latency.** G16 is the only latency gate. It was added on 2026-09-29, before any case
  existed.

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

## Deviations log

None.
