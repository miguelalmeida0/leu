#!/bin/sh
# Scores one development run on P or C (open sets only). Usage: score.sh P|C LABEL
# Reads spikes/v37/readings/LABEL.jsonl, writes spikes/v37/scores/LABEL.score.json.
set -e
SET=$1; LABEL=$2
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
case $SET in P) CASES=p-dev ;; C) CASES=canonical ;; *) echo "set must be P or C"; exit 2 ;; esac
cd "$ROOT/Packages/ShelfCore"
LEU_SPIKE_SCORE_CASES=$ROOT/spikes/v37/cases/$CASES.json LEU_SPIKE_SCORE_SET=$SET LEU_SPIKE_SCORE_LABEL=$LABEL \
  LEU_SPIKE_SCORE_READINGS=$ROOT/spikes/v37/readings/$LABEL.jsonl \
  LEU_SPIKE_SCORE_KEYS=$ROOT/spikes/v37/answer-keys/$SET.json \
  LEU_SPIKE_SCORE_INPUTS=$ROOT/spikes/v37/inputs/$SET.json \
  LEU_SPIKE_SCORE_OUT=$ROOT/spikes/v37/scores/$LABEL.score.json \
  swift test --filter ZZSpikeScoreRun 2>&1 | grep -E "^SPIKE" | grep -v "coarse by category"
