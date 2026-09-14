#!/bin/bash
# Native feature checks only. Preserves the existing library; no reset or fake provider.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/sync-xcode-sources.py
python3 scripts/check-worldclass-offline.py
simulator_id="${SHELF_SIMULATOR_UDID:-A248FB9E-B969-4CF6-A0ED-B2013A3C60A6}"
run_dir="recovery-evidence/explanation-ios-p0/runs/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$run_dir"
set +e
xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath .build/ios-tests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
  -resultBundlePath "$run_dir/native.xcresult" \
  test -only-testing:ShelfTests/ExplainLikeTenFeatureTests \
  -only-testing:ShelfTests/ExplanationAdversarialTests \
  -only-testing:ShelfTests/ExplanationPersistenceTests \
  -only-testing:ShelfUITests/ShelfExplainLikeTenUITests 2>&1 | tee "$run_dir/native.log"
native_status=${PIPESTATUS[0]}
set -e
if [ -d "$run_dir/native.xcresult" ]; then
  if xcrun xcresulttool get test-results summary --path "$run_dir/native.xcresult" \
      > "$run_dir/native-summary.stdout" 2> "$run_dir/summary-export.log"; then
    mv "$run_dir/native-summary.stdout" "$run_dir/native-summary.json"
  fi
  xcrun xcresulttool export attachments --path "$run_dir/native.xcresult" \
    --test-id ShelfExplainLikeTenUITests --output-path "$run_dir/attachments" \
    > "$run_dir/attachment-export.log" 2>&1 || true
fi
echo "Explanation evidence: $run_dir"
exit "$native_status"
