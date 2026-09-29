# V37 spike runner (throwaway)

Calls Apple's on-device model for the V37 capability spike. It is used **only on the Mac** (and,
after the Mac freeze, from the iPhone host app). Branch `test` (the spike branch
`claude/v37-capability-spike`, renamed in the 2026-09-29 branch cleanup); never merged.
The method is fixed by [`../SPIKE_SPEC.md`](../SPIKE_SPEC.md) and
[`../PREREGISTRATION.md`](../PREREGISTRATION.md). This README only says how to run things.

## What is where

| Piece | Where | Runs on |
|---|---|---|
| Export (answer → segments, claims, neighbours) | `Packages/ShelfCore/Tests/ShelfCoreTests/ZZSpike/ZZSpikeSegmenter.swift` (`ZZSpikeExport`) | Linux, Mac |
| Model calls: reading, second opinion, answer keys | this package (`SpikeKit`, `SpikeFoundation`, `spike-runner`) | Mac (iPhone later) |
| Checks V1–V9, second-opinion rules, adapter into the unchanged judge | `ZZSpikeChecks.swift`, `ZZSpikeAdapter.swift` | Linux, Mac |
| Scoring (A0, A, B, C, D), canonical C1–C5 criteria | `ZZSpikeScore.swift`, `ZZSpikeCanonical.swift` (`ZZSpikeScoreRun`) | Linux, Mac |
| Statistics and the G1–G16 checklist | `../score/stats.py` | anywhere |

* **Prompts** are in `../prompts/`: the three approved §6 drafts, verbatim. `spike-runner hash`
  prints the prompt-set SHA-256. It covers the three files and the request layout version in
  `Sources/SpikeKit/Prompts.swift`.
* **Model access.** `SpikeFoundation` compiles only where Foundation Models exists. On Linux the
  runner builds without it and offers only `--model fake`, a stand-in that fills every schema with its
  first allowed values. It is for checking the pipeline and the JSON contract, never for results.
* **Output hygiene.** The runner prints counts and statuses only, never learner text, so the same
  commands are safe on blind sets.

## Commands

```
spike-runner availability
spike-runner hash --prompts ../prompts
spike-runner dry-run --inputs FILE --prompts ../prompts [--keys FILE]
spike-runner answer-keys --inputs FILE --prompts ../prompts --out KEYS.json --details DETAILS.json
spike-runner read --inputs FILE --keys KEYS.json --prompts ../prompts --out RUN.jsonl --device mac --run N [--only ID,ID] [--limit N]
```

* **`availability`** reads `SystemLanguageModel.default.availability` and generates nothing.
* **`dry-run`** renders every request and schema without calling any model, and checks the
  3,500-token budget with a pessimistic estimate (about three bytes per token).
* **`read`** never resumes a run: a run restarts from the beginning (PREREGISTRATION §5). It
  refuses an existing output file unless `--overwrite` is given.

## Preflight on the Mac (no model call, no decryption)

Run from the repository root. The expected results are the Linux results from Step 2.

```
# 1. Branch and machine
git fetch origin test && git checkout test && git pull --ff-only   # the spike branch, renamed `test` in the branch cleanup
git log -1 --oneline
sw_vers; xcodebuild -version; sysctl -n hw.model; swift --version

# 2. Runner: first compile of the Foundation Models engine; tests; availability (reads status only)
(cd spikes/v37/runner && swift build -c release && swift test)          # 8 tests pass
R=spikes/v37/runner/.build/release/spike-runner
$R availability                                                          # available
$R hash --prompts spikes/v37/prompts   # a301def6d16dc1a81e27a51fba1cb719f423d768eae4349d9f9acded87651332

# 3. Gate ciphertexts untouched (no decryption); OpenSSL 3 for the freeze step later
shasum -a 256 spikes/v37/gate/*.enc                                      # = gate/FINGERPRINTS.txt
brew install openssl@3 && "$(brew --prefix openssl@3)/bin/openssl" version

# 4. ShelfCore spike tests on macOS (includes the sealed36 reproduction, totals only)
(cd Packages/ShelfCore && swift test --filter ZZSpike)
#   20 tests pass; SPIKE|S36|totals only|A coarse 82/160 falseMastery 10/104 harmful 23 probes 114
#                                        | A0 coarse 83/160 falseMastery 11/104 harmful 25 probes 113

# 5. The Mac export equals the Linux reference exports
(cd Packages/ShelfCore && for S in P:p-dev C:canonical; do
   LEU_SPIKE_CASES=$PWD/../../spikes/v37/cases/${S#*:}.json LEU_SPIKE_SET=${S%%:*} LEU_SPIKE_EXPORT=/tmp/v37-${S%%:*}.json \
   swift test --filter ZZSpikeExport/testExportInputs; done)
python3 -c "import json; [print(s, 'identical' if json.load(open(f'/tmp/v37-{s}.json')) == json.load(open(f'spikes/v37/inputs/{s}.json')) else 'DIFFERENT') for s in 'PC']"

# 6. Dry runs: every request rendered and sized, no model call
$R dry-run --inputs spikes/v37/inputs/P.json --prompts spikes/v37/prompts  # casesOverBudget=0
$R dry-run --inputs spikes/v37/inputs/C.json --prompts spikes/v37/prompts  # casesOverBudget=0

# 7. The stand-in model end to end through the scorer (no Apple model call)
$R read --model fake --inputs spikes/v37/inputs/C.json --prompts spikes/v37/prompts \
   --out /tmp/v37-C-fake.jsonl --device mac --run 0 --overwrite
(cd Packages/ShelfCore && LEU_SPIKE_SCORE_CASES=$PWD/../../spikes/v37/cases/canonical.json LEU_SPIKE_SCORE_SET=C \
   LEU_SPIKE_SCORE_LABEL=C-fake-mac LEU_SPIKE_SCORE_READINGS=/tmp/v37-C-fake.jsonl \
   LEU_SPIKE_SCORE_INPUTS=$PWD/../../spikes/v37/inputs/C.json LEU_SPIKE_SCORE_OUT=/tmp/v37-C-fake.score.json \
   swift test --filter ZZSpikeScoreRun)
#   SPIKE-CANONICAL|B|passed 2/5, C 2/5, D 2/5, as on Linux (the stand-in's readings mean nothing)
(cd spikes/v37/score && python3 -m unittest test_stats)                  # 10 tests OK
```

## Step 3 on the Mac (after approval): the development loop on P and C only

Run from the repository root. `export/score` run ShelfCore's test target with environment
variables; nothing runs unless the variables are set.

```
# 1. Inputs (committed Linux references: spikes/v37/inputs/{P,C}.json; the Mac export must be identical)
cd Packages/ShelfCore
LEU_SPIKE_CASES=$PWD/../../spikes/v37/cases/p-dev.json LEU_SPIKE_SET=P LEU_SPIKE_EXPORT=/tmp/v37-P.json \
  swift test --filter ZZSpikeExport/testExportInputs
cd ../..

# 2. Answer keys for the development targets (model calls)
R=spikes/v37/runner/.build/release/spike-runner
$R answer-keys --inputs spikes/v37/inputs/P.json --prompts spikes/v37/prompts \
  --out spikes/v37/answer-keys/P.json --details spikes/v37/answer-keys/P.details.json

# 3. One development run (model calls), then score it
$R read --inputs spikes/v37/inputs/P.json --keys spikes/v37/answer-keys/P.json --prompts spikes/v37/prompts \
  --out spikes/v37/readings/P-mac-dev1.jsonl --device mac --run 1
cd Packages/ShelfCore
LEU_SPIKE_SCORE_CASES=$PWD/../../spikes/v37/cases/p-dev.json LEU_SPIKE_SCORE_SET=P LEU_SPIKE_SCORE_LABEL=P-mac-dev1 \
  LEU_SPIKE_SCORE_READINGS=$PWD/../../spikes/v37/readings/P-mac-dev1.jsonl \
  LEU_SPIKE_SCORE_KEYS=$PWD/../../spikes/v37/answer-keys/P.json \
  LEU_SPIKE_SCORE_INPUTS=$PWD/../../spikes/v37/inputs/P.json \
  LEU_SPIKE_SCORE_OUT=$PWD/../../spikes/v37/scores/P-mac-dev1.score.json \
  swift test --filter ZZSpikeScoreRun
cd ../.. && python3 spikes/v37/score/stats.py summary spikes/v37/scores/P-mac-dev1.score.json
```

C (canonical) is the same with `cases/canonical.json`, set `C`, and inputs `inputs/C.json`. The
score prints `SPIKE-CANONICAL|<config>|C1…C5|PASS/FAIL` lines.

## Blind sets (the gate and sealed36): Steps 4–5 only, never before the freeze

* **Decryption and export.** The gate is decrypted only at the frozen-run step, into a temporary
  directory **outside** the repository. Its inputs are exported there too.
* **Outputs.** Answer keys, readings and score files for blind sets go to `blind/` directories.
  `spikes/v37/.gitignore` keeps them out of git.
* **Scoring.** Score with `LEU_SPIKE_SCORE_BLIND=1`. The scorer then refuses any output path
  without `/blind/` and prints aggregates only.
* **Statistics.** `stats.py` prints aggregates only. Its per-author breakdown refuses to print
  groups smaller than 5 on a blind set.

## iPhone host app

The iPhone host app is not built yet. It comes after the Mac freeze (Step 5).
* It will link `SpikeKit` and `SpikeFoundation` from this package, so the device runs the same
  request, schema and engine code.
* It will run the checks and judge on the device, because G16 measures "submit → decision ready"
  on the iPhone. `ConceptKnowledgeBase` is `Codable`, so the Mac can export the knowledge bases the
  app needs.
* Cold launches follow the preregistration: `xcrun devicectl … --terminate-existing`, one answer
  per launch.
