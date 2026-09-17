#!/bin/bash
# Only the remaining real-provider UI test. The app, not this script, writes generation JSON.
set -euo pipefail
cd "$(dirname "$0")/.."
run_dir="recovery-docs/internal/evidence/explanation-ios-p0/runs/$(date +%Y%m%d-%H%M%S)-single-ui"
mkdir -p "$run_dir"
set +e
xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Debug \
  -destination "platform=iOS Simulator,id=A248FB9E-B969-4CF6-A0ED-B2013A3C60A6" \
  -derivedDataPath .build/ios-tests -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO -resultBundlePath "$run_dir/native.xcresult" test \
  "-only-testing:ShelfUITests/ShelfExplainLikeTenUITests/testRealExplanationAndRefinementsStayOnPageThree" \
  2>&1 | tee "$run_dir/native.log"
native_status=${PIPESTATUS[0]}
set -e
if [ -f "$run_dir/native.xcresult/Info.plist" ]; then
  if xcrun xcresulttool get test-results summary --path "$run_dir/native.xcresult" \
      > "$run_dir/summary.stdout" 2> "$run_dir/summary-export.log"; then
    mv "$run_dir/summary.stdout" "$run_dir/summary.json"
  fi
  xcrun xcresulttool export attachments --path "$run_dir/native.xcresult" \
    --test-id ShelfExplainLikeTenUITests --output-path "$run_dir/attachments" \
    > "$run_dir/attachment-export.log" 2>&1 || true
fi
echo "Single-test evidence: $run_dir (xcodebuild exit $native_status)"
exit "$native_status"
