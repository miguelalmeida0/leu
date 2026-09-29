#!/bin/sh
# Repeated-run evaluation of one configuration on the open sets: P three times, C three times, with a
# sample of background load every 30 s (the Apple Intelligence daemons share the on-device model).
# Usage: evaluate.sh NN   → readings/P-mac-devNN-r{1,2,3}, C-mac-devNN-r{1,2,3}, scores, load log.
set -e
NN=$1
ROOT=$(cd "$(dirname "$0")/../../.." && pwd); cd "$ROOT"
R=spikes/v37/runner/.build/release/spike-runner
LOAD=spikes/v37/dev-log/load-dev$NN.txt
(while true; do date '+%H:%M:%S' >> $LOAD; ps -Ao pcpu,comm -r | head -6 | tail -5 | sed 's|.*/||' >> $LOAD; sleep 30; done) &
MON=$!
trap 'kill $MON 2>/dev/null' EXIT
$R hash --prompts spikes/v37/prompts
for K in 1 2 3; do
  $R read --inputs spikes/v37/inputs/P.json --keys spikes/v37/answer-keys/P.json --prompts spikes/v37/prompts \
    --out spikes/v37/readings/P-mac-dev$NN-r$K.jsonl --device mac --run $K --overwrite | tail -1
  $R read --inputs spikes/v37/inputs/C.json --keys spikes/v37/answer-keys/C.json --prompts spikes/v37/prompts \
    --out spikes/v37/readings/C-mac-dev$NN-r$K.jsonl --device mac --run $K --overwrite | tail -1
done
for K in 1 2 3; do
  spikes/v37/runner/score.sh P P-mac-dev$NN-r$K | grep -E "\|D\|cases"
  spikes/v37/runner/score.sh C C-mac-dev$NN-r$K | grep -E "CANONICAL\|D\|passed"
done
