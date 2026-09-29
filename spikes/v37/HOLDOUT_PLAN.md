# V37 — the new independent holdout (NH)

This is the final pass/fail gate (PREREGISTRATION amendment A1). It replaces PG, whose first
passphrase was exposed. **Nothing in this plan runs before the freeze** (`FREEZE.txt` committed on
`test`, with every hash).

## Who sees what

| Role | Sees | Never sees |
|---|---|---|
| Six new author agents (Q–V) | The labelling guide, the addenda below, their own catalogue | Prompts, schemas, code, readings, P, C, PG, sealed36, each other's cases |
| A new blind second labeller | The 60 double-label cases, their catalogue entries, the guide | The first labels |
| Orchestrator (cloud session) | Case ids, problem codes, aggregate counts | Any case text or label |
| Mac development session | Nothing of NH before scoring | NH plaintext, ever |
| Owner | The passphrase file | — |

## Cases: 240 = 6 authors × 40

Each persona is a new agent instance. Earlier authors (J–O, X, Y, Z, W) are never reused.

| Author | Voice | Leads on |
|---|---|---|
| Q | Non-native English, Romance first language | Non-native English, negation |
| R | Rushed phone typist | Typos, terse and very short answers |
| S | Fluent, confident explainer | Long answers with one false clause, fluent but wrong, misconception paraphrases |
| T | Analogies, stories, examples | Analogies, paraphrase, novel vocabulary |
| U | Reasons out loud | Right conclusion / wrong reason, wrong conclusion / plausible reason, causal vs correlational, causal reversal |
| V | Non-native English, East or South Asian first language | Quantifiers (always / never / only), role reversal |

## Targets

* A new seeded partition of ShelfCore's catalogue, seed 3738.
* At least 30 targets across at least 5 documents, and at most 50% of cases on Mobile Mastery.
* The theme concepts (JWT, authentication/authorization, closures) appear on their own concepts.
* Non-theme targets are disjoint from P's.

## Minimum counts across the 240 (tags overlap)

* **As in SPIKE_SPEC §3.3:**

  | Tag | Min |
  |---|---|
  | paraphrase | 40 |
  | novel vocabulary | 40 |
  | right conclusion / wrong reason | 40 |
  | wrong conclusion / plausible reason | 16 |
  | JWT theme | 10 |
  | authentication/authorization theme | 12 |
  | closures theme | 10 |
  | role reversals | 16 |
  | negation | 20 |
  | quantifiers | 16 |
  | causal vs correlational | 12 |
  | long answer with one false clause | 16 |
  | terse (of which ≥ 12 very short) | 24 |
  | typos | 24 |
  | non-native English | 80 |
  | analogies | 16 |
  | misconception paraphrases | 24 |
  | fluent but wrong | 20 |

* **Added for NH:**
  * causal reversal ≥ 16;
  * `reasoningIssue: true` ≥ 60, of which at least 16 are misconception cases. These are the
    "both" cases amendment A2 is about.
* **State mix:** as §3.3, including weak reasoning ≥ 44.

## Labels

* **Base rules.** The V35 guide, the V36 addendum and the spike addendum apply unchanged.
* **Added: `reasoningIssue` (true / false) on every case, independent of the state.** It is true
  when the answer reaches a conclusion through a reason and the reasoning does not hold:
  * a right conclusion from a wrong, circular or unsupported reason;
  * a wrong conclusion from a true or plausible reason;
  * co-occurrence read as cause.

  An answer that gives no reason is false.
* **Double labelling.**
  * The blind second labeller labels 60 cases, 10 per author.
  * Raw coarse agreement must reach 80%, and raw `reasoningIssue` agreement 80%; Cohen's κ is
    reported for both.
  * Otherwise the guide is repaired: at most two rounds, then STOP.

## Validation and sealing

* **Validation.** The validator prints ids, problem codes and counts only. It is extended to
  require `reasoningIssue` and the added quotas. Authors fix their own problems.
* **Sealing.**
  * The passphrase is generated with `openssl rand` **straight into a 0600 file outside the
    repository**. It is never displayed, committed or logged.
  * The owner collects the file; nobody types or pastes the passphrase anywhere this session can
    read.
  * The files are sealed with `openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt`.
  * The plaintext and ciphertext SHA-256 values go into the preregistration.
  * Every plaintext copy is deleted, and that is verified by hash search, as in Step 1.

## The one run

* **Decryption.** On the Mac only, into a temporary directory outside the repository, after the
  freeze.
* **Inputs and answer keys.** Inputs are exported to that directory. Answer keys for NH targets are
  compiled with the frozen compile prompt into `answer-keys/blind/`.
* **Runs.**
  * Frozen Mac runs 1–3.
  * The iPhone 15 Pro run, with the host app built after the freeze.
  * 20 cold launches.
* **Scoring and the decision.**
  * Scored with `LEU_SPIKE_SCORE_BLIND=1`.
  * `stats.py gate` applies every hard gate mechanically; aggregates only.
  * **Run once. Nothing is tuned after the result is seen.**
