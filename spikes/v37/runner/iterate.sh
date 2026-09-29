#!/bin/sh
# One development iteration on the open sets: read P once and C three times with Apple's model, then score.
# Usage: iterate.sh NN   (writes readings/{P,C}-mac-devNN[-rK].jsonl and scores/…score.json)
set -e
NN=$1
ROOT=$(cd "$(dirname "$0")/../../.." && pwd); cd "$ROOT"
R=spikes/v37/runner/.build/release/spike-runner
(cd spikes/v37/runner && swift build -c release 2>&1 | grep -E "error|Build complete")
$R hash --prompts spikes/v37/prompts
$R read --inputs spikes/v37/inputs/P.json --keys spikes/v37/answer-keys/P.json --prompts spikes/v37/prompts \
  --out spikes/v37/readings/P-mac-dev$NN.jsonl --device mac --run $NN --overwrite | tail -1
for K in 1 2 3; do
  $R read --inputs spikes/v37/inputs/C.json --keys spikes/v37/answer-keys/C.json --prompts spikes/v37/prompts \
    --out spikes/v37/readings/C-mac-dev$NN-r$K.jsonl --device mac --run $NN --overwrite | tail -1
done
spikes/v37/runner/score.sh P P-mac-dev$NN | grep -E "\|(B|C|D)\||reasoning|failures|checksFired"
for K in 1 2 3; do spikes/v37/runner/score.sh C C-mac-dev$NN-r$K | grep -E "CANONICAL\|D"; done
python3 spikes/v37/score/stats.py summary spikes/v37/scores/P-mac-dev$NN.score.json | grep -E "^  (B|C|D):"
