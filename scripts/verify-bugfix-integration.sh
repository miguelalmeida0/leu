#!/bin/bash
# Native regression gates only. Actual affected-PDF journeys still need visual review.
# Reuse completed results with --resume; source hashes must match the compiled input.
set -euo pipefail
cd "$(dirname "$0")/.."
device=A248FB9E-B969-4CF6-A0ED-B2013A3C60A6
resume=false
repair_default=false
if [ "$#" -eq 2 ] && { [ "$1" = --resume ] || [ "$1" = --repair-default ]; }; then
  run=$(cd "$2" && pwd)
  resume=true
  if [ "$1" = --repair-default ]; then repair_default=true; fi
elif [ "$#" -eq 0 ]; then
  run="$PWD/docs/design/bugfix-20260914/native-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$run"
else
  echo "Usage: bash scripts/verify-bugfix-integration.sh [--resume|--repair-default evidence-directory]" >&2
  exit 2
fi
echo "Bugfix native evidence: $run"
python3 - "$run" "$resume" "$repair_default" <<'PY'
from pathlib import Path
import hashlib,json,sys
paths=[p for folder in ['Shelf','ShelfTests','ShelfUITests','Packages/ShelfCore','Shelf.xcodeproj','scripts']
       for p in Path(folder).rglob('*') if p.is_file() and not any(x in p.parts for x in ['.build','.swiftpm','__pycache__'])]
current={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
out=Path(sys.argv[1],'source-sha256.json')
if sys.argv[2]=='true':
 original=json.loads(out.read_text())
 changed=sorted(p for p in set(original)|set(current) if original.get(p)!=current.get(p))
 # Package test edits do not affect the iOS build. UI test edits require a
 # refreshed UI runner; all production/native-unit/project inputs remain frozen.
 ui_changes={'ShelfUITests/ShelfStudyInteractionUITests.swift','ShelfUITests/StudyInteractionSupport.swift'}
 allowed={
  'Packages/ShelfCore/Tests/ShelfCoreTests/Learning/SemanticCoreV24Tests.swift',
  'Packages/ShelfCore/Tests/ShelfCoreTests/Learning/SourceIntegrityMigrationTests.swift',
  'scripts/verify-bugfix-integration.sh', 'scripts/verify-bugfix-core-repair.sh'}
 assert set(changed)<=allowed|ui_changes, 'Unexpected inputs changed: '+str(set(changed)-(allowed|ui_changes))
 if set(changed)&ui_changes and sys.argv[3]!='true':
  proof=Path(sys.argv[1],'ui-repair-build-sha256.json')
  ui={p:h for p,h in current.items() if p.startswith('ShelfUITests/')}
  assert proof.exists() and json.loads(proof.read_text())==ui, 'UI runner needs rebuilding; use --repair-default'
 Path(sys.argv[1],'resume-source-diff.json').write_text(json.dumps({'productionBuildInputsUnchanged':True,'changedInputs':changed},indent=2))
else: out.write_text(json.dumps(current,indent=2,sort_keys=True))
PY
common=(-project Shelf.xcodeproj -scheme Shelf -configuration Debug
  -destination "platform=iOS Simulator,id=$device" -derivedDataPath .build/study-home
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO)
if [ "$resume" = false ]; then
  # Native compile first. No package-resolution deletion or simulator reset.
  xcodebuild "${common[@]}" build-for-testing > "$run/build.log" 2>&1
  touch "$run/build-passed"
fi
test -f "$run/build-passed"
python3 scripts/validate.py > "$run/validate.log" 2>&1
if [ "$resume" = true ] && [ -s "$run/contrast.log" ]; then
  python3 - "$run/contrast.log" <<'PY'
from pathlib import Path
import re,sys
log=Path(sys.argv[1]).read_text()
assert re.search(r'Ran 55 tests? in ',log) and log.rstrip().endswith('OK'), 'Saved contrast gate is not green'
print('Reusing saved 55/55 contrast result.')
PY
else
  python3 scripts/test-night-field-contrast.py > "$run/contrast.log" 2>&1
fi
core_current() {
  python3 - "$run" <<'PY'
from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1]); proof=root/'core-verified-sha256.json'
current={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in Path('Packages/ShelfCore').rglob('*')
 if p.is_file() and not any(x in p.parts for x in ['.build','.swiftpm','__pycache__'])}
raise SystemExit(0 if (root/'core-passed').exists() and proof.exists() and json.loads(proof.read_text())==current else 1)
PY
}
if ! core_current; then
  if [ "$repair_default" = true ]; then
    echo "STOP: saved core gate does not match current inputs; no core tests rerun." >&2
    exit 1
  fi
  swift test --package-path Packages/ShelfCore > "$run/core.log" 2>&1
  python3 - "$run/core.log" <<'PY'
from pathlib import Path
import re,sys
expected=sum(len(re.findall(r'func test\w+\s*\(',p.read_text())) for p in Path('Packages/ShelfCore/Tests').rglob('*.swift'))
log=Path(sys.argv[1]).read_text()
assert re.search(r'Executed '+str(expected)+r' tests?, with 0 failures',log), 'Full core XCTest count did not pass'
assert not re.search(r'Test Case .* skipped|with [1-9]\d* tests? skipped',log), 'Skipped tests are not a pass'
PY
  touch "$run/core-passed"
  python3 - "$run/core-verified-sha256.json" <<'PY'
from pathlib import Path
import hashlib,json,sys
paths=[p for p in Path('Packages/ShelfCore').rglob('*') if p.is_file() and not any(x in p.parts for x in ['.build','.swiftpm','__pycache__'])]
Path(sys.argv[1]).write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},indent=2,sort_keys=True))
PY
fi
xcrun simctl bootstatus "$device" -b > "$run/simulator.log" 2>&1
original_size=$(xcrun simctl ui "$device" content_size)
trap 'xcrun simctl ui "$device" content_size "$original_size" >/dev/null 2>&1 || true' EXIT
phase() {
  local name=$1 size=$2 expected=$3 status=0
  local evidence="$run"
  shift 3
  if [ "$name" = default ]; then
    if [ "$repair_default" = true ]; then evidence="$default_repair"
    elif [ -s "$run/default-passed-evidence.txt" ]; then evidence=$(cat "$run/default-passed-evidence.txt"); fi
  fi
  if [ ! -d "$evidence/$name.xcresult" ]; then
    xcrun simctl ui "$device" content_size "$size"
    xcrun simctl ui "$device" content_size > "$evidence/$name-content-size.txt"
    xcodebuild "${common[@]}" -resultBundlePath "$evidence/$name.xcresult" test-without-building "$@" > "$evidence/$name.log" 2>&1 || status=$?
    echo "$status" > "$evidence/$name-exit.txt"
  fi
  if [ -d "$evidence/$name.xcresult" ]; then
    xcrun xcresulttool get test-results summary --path "$evidence/$name.xcresult" > "$evidence/$name-summary.json"
    if [ ! -s "$evidence/$name-attachments/manifest.json" ]; then
      xcrun xcresulttool export attachments --path "$evidence/$name.xcresult" --output-path "$evidence/$name-attachments" > "$evidence/$name-export.log" 2>&1
    fi
  fi
  python3 - "$evidence" "$name" "$expected" <<'PY'
from pathlib import Path
import json,sys
root=Path(sys.argv[1]); name=sys.argv[2]; expected=int(sys.argv[3])
s=json.loads((root/(name+'-summary.json')).read_text())
ok=(root/(name+'-exit.txt')).read_text().strip()=='0' and s.get('result')=='Passed' and s.get('failedTests')==0 and s.get('skippedTests')==0 and s.get('passedTests')==s.get('totalTestCount')==expected
report={'phase':name,'result':'PASS' if ok else 'FAIL','passed':s.get('passedTests'),'failed':s.get('failedTests'),'skipped':s.get('skippedTests'),'expected':expected}
(root/(name+'-report.json')).write_text(json.dumps(report,indent=2));print(json.dumps(report))
raise SystemExit(0 if ok else 1)
PY
}
if [ "$repair_default" = true ]; then
  # Reject a missing/red prerequisite rather than silently rerunning a green gate.
  python3 - "$run" <<'PY'
from pathlib import Path
import json,sys
root=Path(sys.argv[1])
for name,count in [('bugfix-targeted',3),('shelf-full',92),('session-unit',13)]:
 s=json.loads((root/(name+'-report.json')).read_text())
 assert s['result']=='PASS' and s['passed']==count and s['failed']==s['skipped']==0, name+' is not green'
PY
  default_repair="$run/default-repair-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$default_repair"
  python3 - "$default_repair/ui-sha256.json" <<'PY'
from pathlib import Path
import hashlib,json,sys
Path(sys.argv[1]).write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in Path('ShelfUITests').rglob('*') if p.is_file()},indent=2,sort_keys=True))
PY
  # Changed UI test code must be compiled. This executes no unit/session tests;
  # Xcode reuses unchanged production build products when available.
  xcodebuild "${common[@]}" build-for-testing '-only-testing:ShelfUITests' > "$default_repair/build.log" 2>&1
  phase default large 7 '-only-testing:ShelfUITests/ShelfStudyHomeUITests' '-only-testing:ShelfUITests/ShelfStudyInteractionUITests' '-only-testing:ShelfUITests/ShelfLearningOSUITests/test32LearnTodayCreatesLocalStudySession'
  python3 - "$default_repair/ui-sha256.json" <<'PY'
from pathlib import Path
import hashlib,json,sys
current={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in Path('ShelfUITests').rglob('*') if p.is_file()}
assert current==json.loads(Path(sys.argv[1]).read_text()), 'UI test sources changed during verification'
PY
  cp "$default_repair/ui-sha256.json" "$run/ui-repair-build-sha256.json"
  echo "$default_repair" > "$run/default-passed-evidence.txt"
  repair_default=false
fi
phase bugfix-targeted large 3 '-only-testing:ShelfTests/BugfixIntegrationTests'
phase shelf-full large 92 '-only-testing:ShelfTests'
phase session-unit large 13 '-only-testing:ShelfTests/SessionExperienceTests' '-only-testing:ShelfTests/RecallSessionStateTests'
phase default large 7 '-only-testing:ShelfUITests/ShelfStudyHomeUITests' '-only-testing:ShelfUITests/ShelfStudyInteractionUITests' '-only-testing:ShelfUITests/ShelfLearningOSUITests/test32LearnTodayCreatesLocalStudySession'
phase AX1 accessibility-medium 4 '-only-testing:ShelfUITests/ShelfStudyHomeUITests'
phase ui-full large 74 '-only-testing:ShelfUITests'
echo "Regression execution gates PASS. Review attachments and complete the affected-PDF journeys before native certification."
