#!/bin/bash
# Preserve test status. Export diagnostics on failure too, then copy the useful result.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
LOG="${SHELF_QA_LOG:-qa-v24-5.log}"
SUMMARY="${LOG%.log}-summary.txt"
export SHELF_QA_RUN_DIR="$ROOT/.build/qa-runs/v24-5-$(date '+%Y%m%d-%H%M%S')-$$"
mkdir -p "$SHELF_QA_RUN_DIR" || exit 1
date +%s > "$SHELF_QA_RUN_DIR/start-epoch.txt"
printf 'QA workspace: %s\nQA run: %s\n' "$ROOT" "$SHELF_QA_RUN_DIR"
./scripts/qa-native.sh 2>&1 | tee "$LOG"
PIPE_CODES=("${PIPESTATUS[@]}")
STATUS=${PIPE_CODES[0]}
if [[ "$STATUS" -eq 0 && "${PIPE_CODES[1]}" -ne 0 ]]; then STATUS=74; fi
# Verify even a red run, so missing/failed tests are explicitly reported.
python3 scripts/verify-qa-results.py "$LOG" > "$SHELF_QA_RUN_DIR/coverage-check.txt" 2>&1
COVERAGE_STATUS=$?
cat "$SHELF_QA_RUN_DIR/coverage-check.txt" | tee -a "$LOG"
if [[ "$STATUS" -eq 0 && "$COVERAGE_STATUS" -ne 0 ]]; then STATUS=$COVERAGE_STATUS; fi
python3 scripts/collect-qa-diagnostics.py --root "$ROOT" --run-dir "$SHELF_QA_RUN_DIR" \
    --log "$LOG" --qa-status "$STATUS" > "$SHELF_QA_RUN_DIR/export.txt" 2>&1
EXPORT_STATUS=$?
if ! python3 scripts/summarize-qa.py "$LOG" > "$SUMMARY"; then
    printf 'QA summary failed; full log is %s\n' "$LOG" > "$SUMMARY"
fi
cat "$SHELF_QA_RUN_DIR/export.txt" >> "$SUMMARY"
if [[ "$EXPORT_STATUS" -ne 0 ]]; then
    printf '\nDiagnostics export failed; originals remain in .build/results.\n' >> "$SUMMARY"
fi
printf '\nQA process exit code: %s\n' "$STATUS" >> "$SUMMARY"
printf '\n=== Leu V24.5 QA result ===\n'
cat "$SUMMARY"
if command -v pbcopy >/dev/null 2>&1 && pbcopy < "$SUMMARY"; then
    printf '\nSummary copied. Full log: %s\n' "$LOG"
else
    printf '\nClipboard unavailable. Summary saved to %s\n' "$SUMMARY"
fi
exit "$STATUS"
