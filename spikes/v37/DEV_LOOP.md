# V37 development loop — runbook for the Mac session

Apple's on-device model runs only on the Mac (and later the iPhone), so this loop runs there, in a
local Claude Code session on branch `test`. The binding rules are
[PREREGISTRATION.md](PREREGISTRATION.md), including amendments A1–A10. Commands are in
[runner/README.md](runner/README.md).

## What the pipeline must decide per answer (and where)

| The mission asks | Where it happens |
|---|---|
| 1. What the learner claims | The reading: segments with a role |
| 2. Which source claim it refers to | The reading's `claim`, checked by V1 |
| 3. Entails, partially, contradicts, unrelated | The reading's `relation`, checked by V3–V7 and V9, plus D's second opinion |
| 4. Whether the reasoning holds | Reason → conclusion links (V8) and D's reason verdicts; scored by A2 |
| 5. Known or novel misconception | The answer-key mistake id, or "contradicts" with no mistake (novel); checked by V9 and D |
| 6. Whether mastery changes | The unchanged V35 judge and evidence mapper |
| 7. Whether to ask first | The judge: tentative or doubtful readings ask |
| 8. The one next question | The judge and planner, plus A3's rule: a wrong reason is asked about where it breaks |

## Before the first iteration

1. Run the preflight in the runner README. Every expected value must match; the prompt-set hash is
   `0ec5cad0d660258d578d169759ab9bc88fc7d5c2ecf366335b71f9f340afadf1`. If the Foundation
   Models engine does not compile, fix the code (a harness defect) before anything else.
2. Compile answer keys for P and C:

   ```
   spike-runner answer-keys --inputs spikes/v37/inputs/P.json --prompts spikes/v37/prompts \
     --out spikes/v37/answer-keys/P.json --details spikes/v37/answer-keys/P.details.json
   ```

   Do the same for `inputs/C.json` into `answer-keys/C.json`.

## One iteration (budget: 25 in total, within 3 working days)

1. **Make one change**, from the allowed list below. Describe it before running.
2. **Rehash if needed.** If the request layout changed, bump `layoutVersion` in
   `runner/Sources/SpikeKit/Prompts.swift`. Then run `spike-runner hash`.
3. **Recompile answer keys** only if the answer-key prompt changed.
4. **Read P and C** with the Apple model:

   ```
   spike-runner read --inputs spikes/v37/inputs/P.json --keys spikes/v37/answer-keys/P.json \
     --prompts spikes/v37/prompts --out spikes/v37/readings/P-mac-devNN.jsonl --device mac --run NN
   ```

   C is the same, with `--inputs spikes/v37/inputs/C.json --keys spikes/v37/answer-keys/C.json`
   and `--out spikes/v37/readings/C-mac-devNN.jsonl`.
5. **Score both** with `ZZSpikeScoreRun`, as in the README. Then run `stats.py summary`, and look at
   the `SPIKE-CANONICAL` lines.
6. **Log it** in `spikes/v37/dev-log/NN.md`:
   * the change and the prompt hash;
   * for A0, A, B, C and D on P: coarse, paraphrase, novel vocabulary, weak-reasoning recall and
     precision (A2), commit accuracy, follow-up rate, false mastery, harmful writes;
   * canonical results per configuration;
   * checks fired, second-opinion agreement, failure rates, and the Mac median and p95 latency;
   * a failure analysis by class, from P and C only.
7. **Commit and push** to `test`. P and C readings, keys and scores are open data.

### Allowed changes

* The three prompt texts in `prompts/`.
* The request layout (`Requests` in `Prompts.swift`).
* Schema property names and value spellings; short names are fine. The fields stay the same.
* The segmentation reason markers (`SpikeSegmenter`).
* Pruning a check that is wrong more often than right on P. **Never add** a lexical rule, word
  list or special case.
* The second opinion's item cap and priority, and the generation token caps within §6.
* E (the NLI veto), only under PREREGISTRATION §7.

### Never allowed

* Gold labels, P and C cases, canonical criteria, scoring code, thresholds, the judge, the
  planner, the evidence mapper, committed fixtures.
* Any look at PG, sealed36 per-case data, or NH.

## Stops

* **ES1 — end of budget.** If the best of B, C and D is below 65% coarse accuracy on P, STOP. Report
  per amendment A8: the failure taxonomy with examples by class, which part failed, and the
  alternatives compared.
* **ES2 — canonical.** The configuration to freeze must pass canonical 5/5 on 3 consecutive
  development runs; otherwise STOP.
* **Incremental result.** Coarse accuracy at or below 62% on the gate is an architectural failure
  (ES3). No rescue.

## Freeze, then the gate

1. **Write `FREEZE.txt`** (PREREGISTRATION §12): the commit; the primary configuration; the enabled
   checks; the SHA-256 of the prompts, schema, segmenter, checks, adapter, scorer and runner
   sources; the generation settings; the Mac model and OS build. Commit and push it.
2. **The cloud session creates NH** ([HOLDOUT_PLAN.md](HOLDOUT_PLAN.md)). This session never sees
   its plaintext.
3. **Build the iPhone host app** (runner README): SpikeKit and SpikeFoundation, plus the checks and
   judge on the device.
4. **Run the gate** per HOLDOUT_PLAN.md: decrypt on this Mac, three Mac runs, the iPhone run, 20 cold
   launches, blind scoring, `stats.py gate`. Run once.
5. **Report** only the ten A10 items.
