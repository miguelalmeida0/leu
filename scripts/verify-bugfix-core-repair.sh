#!/bin/bash
# Only the two repaired tests first, then full ShelfCore, then resume native gates.
# Keep the original failed core.log and completed build/contrast evidence intact.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -ne 1 ]; then
  echo "Usage: bash scripts/verify-bugfix-core-repair.sh <existing-evidence-directory>" >&2
  exit 2
fi
run=$(cd "$1" && pwd)
test -f "$run/build-passed"
repair="$run/core-repair-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$repair"
python3 - "$repair/source-sha256.json" <<'PY'
from pathlib import Path
import hashlib,json,sys
paths=[p for p in Path('Packages/ShelfCore').rglob('*') if p.is_file() and not any(x in p.parts for x in ['.build','.swiftpm','__pycache__'])]
Path(sys.argv[1]).write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},indent=2,sort_keys=True))
PY
echo "Core repair evidence: $repair"
check_count() {
  python3 - "$1" "$2" <<'PY'
from pathlib import Path
import re,sys
log=Path(sys.argv[1]).read_text(); expected=int(sys.argv[2])
assert re.search(r'Executed '+str(expected)+r' tests?, with 0 failures',log), 'Expected exact passing XCTest count'
assert not re.search(r'Test Case .* skipped|with [1-9]\d* tests? skipped',log), 'Skipped tests are not a pass'
print(str(expected)+'/'+str(expected)+' PASS: '+sys.argv[1])
PY
}
swift test --package-path Packages/ShelfCore --filter \
  'SemanticCoreV24Tests/testSemanticIndexAndQuestionBankPersistTogether|SourceIntegrityMigrationTests/testOldDerivedObjectsAreRetainedForHistoryButNotPlanned' \
  > "$repair/targeted.log" 2>&1
check_count "$repair/targeted.log" 2
swift test --package-path Packages/ShelfCore > "$repair/full-core.log" 2>&1
check_count "$repair/full-core.log" 286
python3 - "$repair/source-sha256.json" <<'PY'
from pathlib import Path
import hashlib,json,sys
paths=[p for p in Path('Packages/ShelfCore').rglob('*') if p.is_file() and not any(x in p.parts for x in ['.build','.swiftpm','__pycache__'])]
current={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
assert current==json.loads(Path(sys.argv[1]).read_text()), 'Source changed during tests; do not certify'
PY
cp "$repair/source-sha256.json" "$run/core-verified-sha256.json"
touch "$run/core-passed"
echo "$repair" > "$run/core-passed-evidence.txt"
bash scripts/verify-bugfix-integration.sh --resume "$run"
