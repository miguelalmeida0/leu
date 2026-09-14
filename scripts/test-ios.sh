#!/bin/bash
# Apple-only PDFKit integration and end-to-end UI tests. Produces a real xcresult.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/common.sh"
require_xcode
choose_simulator
boot_simulator
mkdir -p "$ROOT/.build/results"
RESULT="$ROOT/.build/results/Shelf-$(date '+%Y%m%d-%H%M%S')-$$.xcresult"
if [[ -n "${SHELF_QA_RUN_DIR:-}" ]]; then
  mkdir -p "$SHELF_QA_RUN_DIR"
  printf '%s\n' "$RESULT" >> "$SHELF_QA_RUN_DIR/native-results.txt"
  printf '%s\n' "$SHELF_DEVICE" >> "$SHELF_QA_RUN_DIR/native-devices.txt"
  printf 'test-ios %s\n' "$*" >> "$SHELF_QA_RUN_DIR/native-commands.txt"
fi
set +e
xcodebuild -project "$ROOT/Shelf.xcodeproj" -scheme Shelf -configuration Debug \
  -destination "platform=iOS Simulator,id=$SHELF_DEVICE" -destination-timeout 120 \
  -derivedDataPath "$ROOT/.build/ios-tests" -resultBundlePath "$RESULT" \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test "$@"
STATUS=$?
set -e
printf '\nTest result: %s\nOpen with: open "%s"\n' "$RESULT" "$RESULT"
exit "$STATUS"
