#!/bin/bash
# Convergence gate on the user's specified simulator. No simulator erase/create/seed.
# Existing Study regressions use their established isolated Shelf-UITests fixture;
# new session journeys preserve that test library and never reset it.
set -euo pipefail
cd "$(dirname "$0")/.."
device=A248FB9E-B969-4CF6-A0ED-B2013A3C60A6
run="$PWD/docs/design/session-convergence/native-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$run"
echo "Convergence evidence: $run"
python3 scripts/sync-xcode-sources.py > "$run/membership.log" 2>&1
python3 scripts/validate.py > "$run/validate.log" 2>&1
python3 scripts/check-night-field.py > "$run/night-field.log" 2>&1
python3 scripts/check-study-interactions.py > "$run/interactions.log" 2>&1
python3 scripts/check-ui-test-contract.py > "$run/ui-contract.log" 2>&1
python3 scripts/test-night-field-contrast.py > "$run/contrast.log" 2>&1
python3 - "$run" <<'PY'
from pathlib import Path
import hashlib,json,sys
paths=[p for folder in ['Shelf','ShelfTests','ShelfUITests','Packages/ShelfCore/Sources','Shelf.xcodeproj'] for p in Path(folder).rglob('*') if p.is_file()]
Path(sys.argv[1],'source-sha256.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},indent=2))
PY
xcrun simctl bootstatus "$device" -b > "$run/simulator.log" 2>&1
original_size=$(xcrun simctl ui "$device" content_size)
trap 'xcrun simctl ui "$device" content_size "$original_size" >/dev/null 2>&1 || true' EXIT
common=(-project Shelf.xcodeproj -scheme Shelf -configuration Debug
  -destination "platform=iOS Simulator,id=$device" -derivedDataPath .build/study-home
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO)
# Compile all changed app/test inputs once. Every execution below reuses this build.
xcodebuild "${common[@]}" build-for-testing > "$run/build.log" 2>&1
phase() {
  local name=$1 size=$2 expected=$3 status=0
  shift 3
  xcrun simctl ui "$device" content_size "$size"
  xcrun simctl ui "$device" content_size > "$run/$name-content-size.txt"
  xcodebuild "${common[@]}" -resultBundlePath "$run/$name.xcresult" test-without-building "$@" > "$run/$name.log" 2>&1 || status=$?
  if [ -d "$run/$name.xcresult" ]; then
    xcrun xcresulttool get test-results summary --path "$run/$name.xcresult" > "$run/$name-summary.json"
    xcrun xcresulttool get test-results tests --path "$run/$name.xcresult" > "$run/$name-tests.json"
    xcrun xcresulttool export attachments --path "$run/$name.xcresult" --output-path "$run/$name-attachments"
  fi
  if [ "$status" -ne 0 ]; then
    echo "STOP: $name exit $status; see $run/$name.log" >&2
    exit "$status"
  fi
  python3 - "$run/$name-summary.json" "$expected" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); expected=int(sys.argv[2])
print(sys.argv[1],s['result'],s['passedTests'],'passed',s['failedTests'],'failed',s['skippedTests'],'skipped')
assert s['result']=='Passed' and s['failedTests']==0 and s['skippedTests']==0
assert s['passedTests']==s['totalTestCount'] and s['passedTests']>0
if expected: assert s['passedTests']==expected
PY
}
phase session-unit large 13 '-only-testing:ShelfTests/SessionExperienceTests' '-only-testing:ShelfTests/RecallSessionStateTests'
phase unit large 0 '-only-testing:ShelfTests'
phase default large 7 '-only-testing:ShelfUITests/ShelfStudyHomeUITests' '-only-testing:ShelfUITests/ShelfStudyInteractionUITests' '-only-testing:ShelfUITests/ShelfLearningOSUITests/test32LearnTodayCreatesLocalStudySession'
phase AX1 accessibility-medium 4 '-only-testing:ShelfUITests/ShelfStudyHomeUITests'
phase session-compatibility large 2 '-only-testing:ShelfUITests/ShelfWorldClassUITests/test53ActiveStudyContextSurvivesInterruption' '-only-testing:ShelfUITests/ShelfRecoveryV25UITests/test57ConfidenceControlsHaveEqualGeometryAndCompleteLabels'
phase sessions-default large 5 '-only-testing:ShelfUITests/ShelfSessionExperienceUITests'
phase sessions-AX1 accessibility-medium 5 '-only-testing:ShelfUITests/ShelfSessionExperienceUITests'
echo "All native execution gates passed. Inspect both session attachment sets before visual certification."
