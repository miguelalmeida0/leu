#!/bin/bash
# Run in local Terminal. Uses only the existing isolated Shelf-UITests library.
set -euo pipefail
cd "$(dirname "$0")/.."
device=A248FB9E-B969-4CF6-A0ED-B2013A3C60A6
run="$PWD/docs/design/study-home-docs/internal/evidence/native-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$run"
echo "Study Home evidence: $run"
python3 scripts/test-night-field-contrast.py > "$run/contrast.log" 2>&1
python3 scripts/check-night-field.py > "$run/night-field.log"
python3 scripts/check-study-interactions.py > "$run/interactions.log"
python3 scripts/validate.py > "$run/validate.log"
common=(-project Shelf.xcodeproj -scheme Shelf -configuration Debug
  -destination "platform=iOS Simulator,id=$device"
  -derivedDataPath .build/study-home CODE_SIGNING_ALLOWED=NO)
xcodebuild "${common[@]}" build > "$run/build.log" 2>&1
xcrun simctl bootstatus "$device" -b > "$run/simulator.log" 2>&1
original_size=$(xcrun simctl ui "$device" content_size)
printf '%s\n' "$original_size" > "$run/original-content-size.txt"
trap 'xcrun simctl ui "$device" content_size "$original_size" >/dev/null 2>&1 || true' EXIT

export_results() {
  local variant=$1
  if [ -d "$run/$variant.xcresult" ]; then
    xcrun xcresulttool get test-results summary --path "$run/$variant.xcresult" > "$run/$variant-summary.json"
    xcrun xcresulttool export attachments --path "$run/$variant.xcresult" --output-path "$run/$variant-attachments"
  fi
}

result=0
for variant in default AX1; do
  size=large
  if [ "$variant" = AX1 ]; then size=accessibility-medium; fi
  xcrun simctl ui "$device" content_size "$size"
  xcrun simctl ui "$device" content_size > "$run/$variant-content-size.txt"
  extra=()
  if [ "$variant" = default ]; then
    extra=('-only-testing:ShelfUITests/ShelfStudyInteractionUITests'
      '-only-testing:ShelfUITests/ShelfLearningOSUITests/test32LearnTodayCreatesLocalStudySession')
  fi
  set +e
  xcodebuild "${common[@]}" -parallel-testing-enabled NO -resultBundlePath "$run/$variant.xcresult" test \
    '-only-testing:ShelfUITests/ShelfStudyHomeUITests' "${extra[@]}" > "$run/$variant-ui.log" 2>&1
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then result=$status; fi
  export_results "$variant"
done
echo "Study Home native test exit: $result"
echo "Inspect real default/AX1 attachments before certifying the redesign."
exit "$result"
