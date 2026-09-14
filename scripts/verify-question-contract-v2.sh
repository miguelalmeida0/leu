#!/bin/bash
# V2 targeted deterministic -> three independent real model tests -> full ShelfTests.
# No Study UI rerun, simulator erase, model fallback, or fixture output injection.
set -euo pipefail
cd "$(dirname "$0")/.."
device=A248FB9E-B969-4CF6-A0ED-B2013A3C60A6
run="$PWD/docs/design/question-contract-v2/native-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$run"
echo "Question V2 evidence: $run"
python3 scripts/validate.py > "$run/validate.log" 2>&1
python3 - "$run" <<'PY'
from pathlib import Path
import hashlib,json,sys
paths=[p for folder in ['Shelf','ShelfTests','ShelfUITests','Packages/ShelfCore/Sources','Shelf.xcodeproj'] for p in Path(folder).rglob('*') if p.is_file()]
Path(sys.argv[1],'source-sha256.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},indent=2))
PY
# The package tests include all V2 safety/normalization checks and unchanged legacy admission tests.
swift test --package-path Packages/ShelfCore --filter 'GroundedQuestionContractTests|LearningCandidateValidatorTests' > "$run/core-tests.log" 2>&1
python3 - "$run/core-tests.log" <<'PYTEST'
import re,sys
from pathlib import Path
files=[Path('Packages/ShelfCore/Tests/ShelfCoreTests/Learning')/name for name in ['GroundedQuestionContractTests.swift','LearningCandidateValidatorTests.swift']]
expected=sum(len(re.findall(r'    func test\w+\(',p.read_text())) for p in files)
log=Path(sys.argv[1]).read_text()
assert re.search(r'Executed '+str(expected)+r' tests?, with 0 failures',log), 'Targeted XCTest count or no-skip gate did not pass'
PYTEST
xcrun simctl bootstatus "$device" -b > "$run/simulator.log" 2>&1
common=(-project Shelf.xcodeproj -scheme Shelf -configuration Debug
  -destination "platform=iOS Simulator,id=$device" -derivedDataPath .build/study-home
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO)
xcodebuild "${common[@]}" build-for-testing > "$run/build.log" 2>&1
phase() {
  local name=$1 expected=$2 status=0
  shift 2
  xcodebuild "${common[@]}" -resultBundlePath "$run/$name.xcresult" test-without-building "$@" > "$run/$name.log" 2>&1 || status=$?
  echo "$status" > "$run/$name-exit.txt"
  if [ -d "$run/$name.xcresult" ]; then
    xcrun xcresulttool get test-results summary --path "$run/$name.xcresult" > "$run/$name-summary.json" || return 1
    xcrun xcresulttool export attachments --path "$run/$name.xcresult" --output-path "$run/$name-attachments" > "$run/$name-export.log" 2>&1 || return 1
  fi
  # Always record per-run metrics, including a rejection or provider error.
  python3 - "$run" "$name" "$expected" "$status" <<'PY'
from pathlib import Path
import json,sys
run=Path(sys.argv[1]); name=sys.argv[2]; expected=int(sys.argv[3]); status=int(sys.argv[4])
summary=run/(name+'-summary.json')
s=json.loads(summary.read_text()) if summary.exists() else {}
manifest=run/(name+'-attachments/manifest.json')
metrics=[]
if manifest.exists():
 for entry in json.loads(manifest.read_text()):
  for a in entry.get('attachments',[]):
   if a.get('suggestedHumanReadableName','').startswith('real-model-v2-metrics'):
    metrics.append(json.loads((manifest.parent/a['exportedFileName']).read_text()))
ok=status==0 and s.get('result')=='Passed' and s.get('failedTests')==0 and s.get('skippedTests')==0 and s.get('passedTests')==expected and s.get('totalTestCount')==expected
if name.startswith('real-'):
 ok=ok and len(metrics)==1 and metrics[0]['generated']>0 and metrics[0]['accepted']>0 and metrics[0]['representableClaims']>0 and metrics[0]['rejected']==0 and not metrics[0].get('inferenceErrors')
report={'phase':name,'result':'PASS' if ok else 'FAIL','xcodebuildExit':status,'passed':s.get('passedTests'),'failed':s.get('failedTests'),'skipped':s.get('skippedTests'),'metrics':metrics}
(run/(name+'-report.json')).write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
sys.exit(0 if ok else 1)
PY
}
phase deterministic-ios 2 '-only-testing:ShelfTests/QuestionContractV2IntegrationTests'
green=1
for attempt in 1 2 3; do
  if ! phase "real-$attempt" 1 '-only-testing:ShelfTests/LearningRealModelP0Tests/testRealReactInferenceValidationPersistenceAndPlanning'; then
    green=0
  fi
done
if [ "$green" -ne 1 ]; then
  echo "STOP: at least one real-model gate failed. Full ShelfTests not run. See $run" >&2
  exit 1
fi
# Original 87 native unit tests plus two V2 integration tests.
phase full-shelf 89 '-only-testing:ShelfTests'
echo "Question Contract V2 native gates PASS. Evidence: $run"
