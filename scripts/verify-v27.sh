#!/bin/bash
# Focused V27 gates only. Does not run historical UI/core/session/contrast sweeps.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$(basename "$PWD")" != LeuV27Intelligence ]; then
  echo "Run in the isolated LeuV27Intelligence checkout." >&2
  exit 1
fi
if [ "$#" -gt 0 ]; then
  if [ "$(basename "$1")" != javascript_midlevel_interview_mobile_mastery.pdf ] || [ ! -f "$1" ]; then
    echo "Expected the actual javascript_midlevel_interview_mobile_mastery.pdf file." >&2
    exit 1
  fi
  export LEU_MOBILE_MASTERY_PDF="$1"
fi
mkdir -p docs/v27/evidence
python3 scripts/register-v27-sources.py
python3 scripts/test-v27-host.py
python3 scripts/probe-v27-model.py
run="docs/v27/evidence/native-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$run"
xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Debug \
  -destination "platform=iOS Simulator,id=${LEU_SIMULATOR_ID:-A248FB9E-B969-4CF6-A0ED-B2013A3C60A6}" \
  -derivedDataPath .build/v27-native -resultBundlePath "$run/v27.xcresult" \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test \
  '-only-testing:ShelfUITests/ShelfV27IntelligenceUITests' > "$run/ui.log" 2>&1
xcrun xcresulttool get test-results summary --path "$run/v27.xcresult" > "$run/summary.json"
xcrun xcresulttool export attachments --path "$run/v27.xcresult" --output-path "$run/attachments"
if [ -z "${LEU_MOBILE_MASTERY_PDF:-}" ]; then
  echo "Focused gates ran; mobile_mastery certification is still OPEN (PDF not supplied)." >&2
  exit 2
fi
echo "Evidence: $run. Inspect the mobile_mastery proposals and screenshots before certifying product quality."
