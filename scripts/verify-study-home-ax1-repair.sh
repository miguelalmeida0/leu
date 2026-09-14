#!/bin/bash
# Target the repaired AX1 journey first, then reuse its build for all four AX1 tests.
# The existing default results are read-only and never selected for execution.
set -euo pipefail
cd "$(dirname "$0")/.."
device=A248FB9E-B969-4CF6-A0ED-B2013A3C60A6
run="$PWD/docs/design/study-home-evidence/native-20260913-111815/ax1-repair/run-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$run"
echo "AX1 repair evidence: $run"
xcrun simctl bootstatus "$device" -b > "$run/simulator.log" 2>&1
original_size=$(xcrun simctl ui "$device" content_size)
trap 'xcrun simctl ui "$device" content_size "$original_size" >/dev/null 2>&1 || true' EXIT
xcrun simctl ui "$device" content_size accessibility-medium
xcrun simctl ui "$device" content_size > "$run/content-size.txt"
common=(-project Shelf.xcodeproj -scheme Shelf -configuration Debug
  -destination "platform=iOS Simulator,id=$device"
  -derivedDataPath .build/study-home -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO)

run_phase() {
  local phase=$1 action=$2 selector=$3 expected=$4 status=0
  xcodebuild "${common[@]}" -resultBundlePath "$run/$phase.xcresult" "$action" \
    "-only-testing:$selector" > "$run/$phase-ui.log" 2>&1 || status=$?
  if [ -d "$run/$phase.xcresult" ]; then
    xcrun xcresulttool get test-results summary --path "$run/$phase.xcresult" > "$run/$phase-summary.json"
    xcrun xcresulttool export attachments --path "$run/$phase.xcresult" --output-path "$run/$phase-attachments"
  fi
  if [ "$status" -ne 0 ]; then
    echo "$phase failed (exit $status). Further tests were not started." >&2
    exit "$status"
  fi
  python3 - "$run/$phase-summary.json" "$expected" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
count = int(sys.argv[2])
assert s["result"] == "Passed" and s["passedTests"] == count
assert s["totalTestCount"] == count and s["failedTests"] == 0 and s["skippedTests"] == 0
print(f"PASS: {count}/{count}, zero failures/skips")
PY
}

# The edited test must be compiled once. No clean build, default tests or product edits.
run_phase single test 'ShelfUITests/ShelfStudyHomeUITests/testEmptyStudyFieldsAndExistingDestinations' 1
run_phase full test-without-building 'ShelfUITests/ShelfStudyHomeUITests' 4
echo "AX1 4/4 GREEN. Existing default 7/7 evidence was not changed."
echo "Inspect empty-builder-duration-reachable in $run/full-attachments/manifest.json."
