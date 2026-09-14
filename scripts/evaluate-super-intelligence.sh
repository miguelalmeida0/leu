#!/usr/bin/env bash
# Certification harness for Packages/LeuReasoningCore.
#
# Runs two layers:
#   1. the Swift certification suite (requires a Swift toolchain), which
#      computes every metric by running the real engine over the golden corpus;
#   2. a toolchain-free structural audit of the corpus and the package, which
#      runs anywhere Python 3 is available.
#
# Usage:
#   scripts/evaluate-super-intelligence.sh                 # both layers
#   scripts/evaluate-super-intelligence.sh --structural    # layer 2 only
#   LEU_GOLDEN_CORPUS=/path/to/corpus.json scripts/evaluate-super-intelligence.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="$ROOT/Packages/LeuReasoningCore"
REPORT_DIR="${LEU_EVAL_OUTPUT:-$ROOT/evidence/super-intelligence}"
mkdir -p "$REPORT_DIR"

structural_only=0
[ "${1:-}" = "--structural" ] && structural_only=1

status=0

echo "== structural audit =="
python3 "$ROOT/scripts/audit-super-intelligence.py" \
    --package "$PACKAGE" \
    --corpus "${LEU_GOLDEN_CORPUS:-$PACKAGE/Tests/LeuReasoningCoreTests/Fixtures/golden-corpus.json}" \
    --out "$REPORT_DIR/structural-audit.json" || status=1

if [ "$structural_only" = "1" ]; then
    exit "$status"
fi

echo
echo "== swift certification suite =="
if ! command -v swift >/dev/null 2>&1; then
    echo "SKIPPED: no Swift toolchain on PATH."
    echo "         Run this script on a machine with Xcode or a Swift toolchain"
    echo "         to produce the engine metrics; the structural audit above is"
    echo "         toolchain-free and already ran."
    exit "$status"
fi

export LEU_EVAL_REPORT="$REPORT_DIR/evaluation-report.json"
( cd "$PACKAGE" && swift build ) || status=1
( cd "$PACKAGE" && swift test ) || status=1

if [ -f "$LEU_EVAL_REPORT" ]; then
    echo
    echo "== metrics =="
    python3 - "$LEU_EVAL_REPORT" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))

def rate(num, den):
    return "n/a" if not den else f"{num}/{den} ({num / den:.0%})"

extraction = report["atomExtraction"]
print("ATOM EXTRACTION")
print("  extracted           ", rate(extraction["extracted"], extraction["sentences"]))
for field, label in [("subjectPreserved", "subject preserved   "),
                     ("qualifierPreserved", "qualifiers preserved"),
                     ("negationPreserved", "negation preserved  "),
                     ("numberPreserved", "numbers preserved   "),
                     ("identifierPreserved", "identifiers preserved")]:
    print(f"  {label}", rate(extraction[field], extraction["extracted"]))

relationships = report["relationships"]
print("RELATIONSHIPS")
print("  admitted            ", relationships["admitted"])
print("  source-supported    ", relationships["sourceSupported"])
print("  inferred            ", relationships["inferred"])
print("  false positives     ", relationships["falsePositives"])

alignment = report["learnerAlignment"]
print("LEARNER ALIGNMENT")
print("  paraphrase accepted ", rate(alignment["paraphraseAccepted"], alignment["paraphraseCases"]))
print("  contradiction caught", rate(alignment["contradictionRejected"], alignment["contradictionCases"]))
print("  overgeneralisation  ", rate(alignment["overgeneralisationDetected"], alignment["overgeneralisationCases"]))
print("  mixed cases correct ", rate(alignment["mixedCorrect"], alignment["mixedCases"]))

chains = report["chains"]
print("CAUSAL CHAINS")
print("  reproduced          ", rate(chains["reproduced"], chains["expected"]))
print("  unsupported bridges ", chains["unsupportedBridges"])
print("  provenance gaps     ", chains["incompleteProvenance"])

counterfactuals = report["counterfactuals"]
print("COUNTERFACTUALS")
print("  grounded            ", counterfactuals["groundedConsequences"])
print("  invented            ", counterfactuals["inventedConsequences"])

synthesis = report["synthesis"]
print("SYNTHESIS")
print("  lines rendered      ", synthesis["lines"])
print("  unsupported         ", synthesis["unsupportedStatements"])
print("  manufactured contrast", synthesis["manufacturedContrasts"])

hard = (synthesis["unsupportedStatements"] + chains["unsupportedBridges"]
        + counterfactuals["inventedConsequences"] + relationships["falsePositives"])
print()
print("HARD GATE (must be 0):", hard)
sys.exit(0 if hard == 0 else 1)
PY
    [ $? -ne 0 ] && status=1
fi

exit "$status"
