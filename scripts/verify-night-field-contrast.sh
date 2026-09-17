#!/bin/bash
# Native verification. Existing UI tests use the app's isolated Shelf-UITests store.
set -euo pipefail
cd "$(dirname "$0")/.."
run="$PWD/docs/design/docs/internal/evidence/native-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$run"
python3 scripts/check-night-field.py | tee "$run/night-field.log"
python3 scripts/test-night-field-contrast.py > "$run/contrast.log" 2>&1
python3 scripts/validate.py | tee "$run/validate.log"
common=(-project Shelf.xcodeproj -scheme Shelf -configuration Debug
  -destination 'platform=iOS Simulator,id=A248FB9E-B969-4CF6-A0ED-B2013A3C60A6'
  -derivedDataPath .build/night-field-contrast CODE_SIGNING_ALLOWED=NO)
xcodebuild "${common[@]}" build > "$run/build.log" 2>&1
set +e
xcodebuild "${common[@]}" -parallel-testing-enabled NO -resultBundlePath "$run/ui.xcresult" test \
  '-only-testing:ShelfUITests' > "$run/ui.log" 2>&1
status=$?
set -e
if [ -d "$run/ui.xcresult" ]; then
  xcrun xcresulttool get test-results summary --path "$run/ui.xcresult" > "$run/summary.json"
  xcrun xcresulttool export attachments --path "$run/ui.xcresult" --output-path "$run/attachments"
fi
echo "Native evidence: $run"
echo "Screenshots still require visual review, including the 16-screen AX1 pass."
exit "$status"
