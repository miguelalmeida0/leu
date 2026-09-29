# V37 spike — Step 2 notes (harness built; no model run)

Step 2 built the throwaway harness and checked it on Linux with synthetic readings.
* No Apple model was called.
* The gate was not decrypted.
* No production source, `Package.swift`, script, V35 or V36 branch changed.
* No prompt was developed: `prompts/*.txt` are the approved §6 drafts, copied verbatim.

## What exists

| Piece | Files |
|---|---|
| Export: segments, aliases, neighbours | `ZZSpike/ZZSpikeContract.swift`, `ZZSpikeSegmenter.swift`; Linux references in `inputs/{P,C}.json` |
| Checks V1–V9 and the second-opinion rules | `ZZSpike/ZZSpikeChecks.swift` |
| Adapter into the unchanged judge, planner and evidence mapper | `ZZSpike/ZZSpikeAdapter.swift` |
| Scorer (A0, A, B, C, D) and the canonical C1–C5 checker | `ZZSpike/ZZSpikeScore.swift`, `ZZSpikeCanonical.swift` |
| Tests and synthetic readings | `ZZSpike/ZZSpikeAdapterTests.swift`, `ZZSpikeFixtures.swift` |
| Mac runner: request layout, schemas, item selection, answer keys, Foundation Models engine, CLI | `runner/` (see `runner/README.md`) |
| Statistics and the G1–G16 checklist | `score/stats.py`, `score/test_stats.py` |

## Checked on Linux

* **ShelfCore spike tests: 20 pass**, among them:
  * C1–C5 with careful synthetic readings pass every §3.2 criterion in B, C and D;
  * careless readings fail the criteria they should;
  * one test per check (V1, V2, V3, V4, V5, V7, V8, V9);
  * the D rules;
  * Tier 0 fallbacks (a failed call uses V35's decision and counts as a failure; an empty answer
    uses V35 and does not);
  * the scorer end to end, including its refusal to write blind output outside `blind/`.
* **Harness sanity (§3.4)** reproduces the recorded totals exactly:

  | | Coarse | False mastery | Harmful writes | Probes |
  |---|---|---|---|---|
  | A, V36 | 82/160 (51%) | 10/104 | 23 | 114 |
  | A0, V35 | 83/160 (52%) | 11/104 | 25 | 113 |

* **Development baselines on P** (open): see "P baselines" below.
* **Runner: 8 tests pass** (the SHA-256 vectors, the request layout, the schemas, alias mapping,
  item selection and cap, failure recording, the answer-key self-check, and the stand-in model).
* **The CLI runs end to end with the stand-in model.** Its JSONL decodes in the ShelfCore scorer,
  whose recomputed inputs equal the runner's (0 mismatches).
* **Dry-run prompt estimates** (pessimistic, about three bytes per token; budget 3,500): at most
  910 for the reading, 1,692 for the worst-case 8-pair second opinion, and 593 for the answer key.
* **Prompt-set SHA-256:** `a301def6d16dc1a81e27a51fba1cb719f423d768eae4349d9f9acded87651332`.
* **`stats.py`: 10 tests pass.**
* **Not compiled here:** `runner/Sources/SpikeFoundation` (Foundation Models exists only on
  Apple platforms). It compiles for the first time in the Mac preflight.

## Implementation decisions (within the spec; you may overrule any)

1. **The judge.** The adapter feeds this branch's `UnderstandingJudge`: V35's rules plus V36's
   evidence-only rules.
   * The V36 semantic inputs stay empty, so no semantic rule fires.
   * The one V36-era input used is `ClauseSignal.reason`, which §7's row "an unconfirmed reason →
     asked" needs.
2. **A confirmed wrong reason with no marker of its own** (it was marked by ", so" or only by its
   role) gets "because" in its signal text. The judge's own weak-reasoning rule then applies
   (§7: "the reason segment marked unsupported, keeping its marker").
3. **V7's "content words"** are the words outside V35's own function-word lists, minus the
   concept's name.
   * The lists are `ClauseLexicon`'s auxiliaries, determiners, prepositions and subordinators, plus
     the connectives of V35's keyword-list rule.
   * **Why:** the first version used V35's distinctive-term filter. That filter counts C1's "It
     checks that the person is really who they claim to be." as 3 content words, so C and D could
     never pass C1.
4. **Neighbours** (§5: at most 4, contrast partner first).
   * Claims belong to the concept V35's own owner rule names.
   * After the contrast partner come the neighbours whose definitions share the most stems with
     the target's core and supporting claims.
   * **Why:** the first version grouped claims by their raw subject and listed non-concepts such as
     "assigning them".
5. **Wrong ideas.**
   * An over-generalization read by the model takes V35's form: partial coverage plus an
     over-generalization issue.
   * A doubtful reversal or over-generalization becomes an unclear contradiction (§7, "Doubtful
     contradiction").
6. **Canonical checker.**
   * "Committed or asked as a misconception check" means one of two things: the state is
     misconception with no question, or the question's alternatives include misconception.
   * "A mistake about copying values" means the matched answer-key mistake's text contains `cop…`.
   * "About signing versus encryption" means it contains `encrypt`, `read`, `secret`, `hidden` or
     `private`.
7. **Answer-key grounding** (runner side): a mistake must share a content-word stem with its claim,
   or with the definition of the neighbour it confuses. This uses simple English stemming, not
   ShelfCore's lexicon.
8. **Second-opinion items.** A segment that is both a contradiction and a linked reason gets both
   items; the checks decide after V8 which one applies.
9. **Failure accounting.**
   * A V1 structural failure counts as a schema error.
   * An empty answer (no segment) makes no call, uses V35 and is not a failure.
   * On a timeout the call latency is taken when the timeout fires; the answer's total may include
     the cancelled call winding down.
10. **The iPhone host app** comes after the Mac freeze. Step 2's scope was the Mac runner, and
    `runner/README.md` records the design.

## Findings for your decision before Step 3

These were found with synthetic readings through the unchanged judge and pinned by
`testCanonicalTensionsWithTheUnchangedJudge`. Nothing was changed.

1. **C3 on the supporting claim.**
   * §3.2 allows C3 to be read against Closure's supporting "retain access" claim (`329d…`).
   * Read that way, it ends fragile and asked, because the judge credits core claims only.
   * C3 passes only when the reading picks the definition.
2. **Partial entailment for C1 and C3.**
   * Read as *partially* entailing the definition, C1 and C3 reach only "fragile" (coverage 0.3
     gives the level "partial").
   * §3.2 allows "entails or partially entails", but only "entails" can meet the state criterion.
3. **C4 under D.**
   * If the second opinion calls the copying reason "part" or "same", the judge asks about
     Closure's how/why claim. That is its purpose claim (`ea1f…`), not the access claim, so C4's
     question criterion fails.
   * With "opposite" or "different", C4 passes (weak reasoning, committed).
4. **C5 against a supporting claim.** C5's wrong idea contradicts a supporting claim (`f8f6…`).
   * The judge commits the misconception, and C5's "committed or asked" criterion passes.
   * The unchanged evidence mapper records nothing for supporting claims, so the learner model
     receives no misconception.

**Consequence:** ES2 (canonical 5/5 on three consecutive development runs) depends on:
* the model choosing the definition claim, and entailment, for C1 and C3;
* D's verdict on C4's reason.

## P baselines (open development set, deterministic)

From `ZZSpikeScoreRun` with A0 and A only (no readings). 95% Wilson intervals are in brackets.

| Metric (gate) | A0, V35 | A, V36 |
|---|---|---|
| Coarse accuracy (G1) | 37/80, 46% [36–57] | 37/80, 46% [36–57] |
| Paraphrase (G2) | 6/25, 24% | 6/25, 24% |
| Novel vocabulary (G3) | 19/56, 34% | 19/56, 34% |
| Weak-reasoning recall (G4) | 0/13 | 0/13 |
| Weak-reasoning precision (G5) | 0/1 | 0/2 |
| Commit accuracy (G6) | 10/24, 42% | 10/23, 43% |
| Follow-up rate (G7) | 56/80, 70% | 57/80, 71% |
| False mastery (G8) | 3/58, 5% | 2/58, 3% |
| Harmful writes (G9) | 10/80, 12.5% | 8/80, 10% |

## Final verification (2026-09-29)

Run on the code at `071379e`. The later commits change only documentation and add a data file
that no test reads.

* **ShelfCore clean build** from an empty build directory: exit 0, **0 warnings**.
* **Full ShelfCore suite: 495 tests, 0 failures**, including V34–V36 and the 20 spike tests.
* **Runner clean build:** 0 warnings; 8 tests pass.
* **`stats.py`:** 10 tests pass.
* **`scripts/validate.py`** (the 300-line rule and structure checks) and
  **`scripts/check-learning-offline.py`** pass.

## Branch cleanup (2026-09-29)

At your instruction the repository keeps three branches:

| Branch | Holds |
|---|---|
| `main` | Untouched |
| `dev` | `6e19a6d`, V36 |
| `test` | This spike branch, renamed |

The other branches are removed. Their tips are listed so any one can be restored with
`git push origin <sha>:refs/heads/<name>` while GitHub still holds the objects.

| Removed branch | Tip | Commits in none of main, dev or test |
|---|---|---|
| `claude/leu-v34-verification-handoff` | `3fbd9aba10b17d9223d262ef313378f80a24caa0` | 0 |
| `claude/leu-v35-diagnosis-generalization` | `759dc88c90b14765f0c9352e4c4eadce47cf256b` | 0 |
| `claude/leu-v36-semantic-understanding` | `6e19a6d29792bd56a8e188d9dfc4d509114e1079` | 0 |
| `claude/super-intelligence` | `30ab6d5a65e6cb5b040c4cd924bcfc46a32df21e` | 0 |
| `claude/super-intelligence-core-v1` | `eb6b76ce307d41a067cb805e3e1a9895644d386c` | 2 |
| `claude/v37-capability-spike` | continues as `test` | 0 |
| `codex/qwen-local-understanding` | `e4168a9acf5dd233d4d96cce04c9f510b57bb56e` | 9 |
| `codex/v28-living-knowledge` | `8249120ce9cf47ae733e3df50aec480b52dab3f8` | 2 |
| `codex/v28.1-instant-intelligence` | `09854ebccddd0324fd8789ea7f95b389cd0c54ab` | 4 (still reachable from tag `v28.1-rc1`) |
| `codex/v29-real-reasoning` | `cab3655d927435f2f2143fc9598468bb65fc4e9e` | 3 |
| `codex/v29.1-teach-integration` | `16d550ec41c61d6d6e1e4177fda4db9c4e5ad857` | 5 |

**The fallback's manifest is preserved.** PREREGISTRATION §8 cites the model manifest on
`codex/qwen-local-understanding`. A byte-identical copy (SHA-256 `86ad664f…`) is kept at
`fallback/MODEL_MANIFEST.json`.
