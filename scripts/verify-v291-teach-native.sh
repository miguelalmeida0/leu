#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
evidence="$PWD/evidence/v29.1/native-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$evidence"
xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Debug \
  -destination 'platform=iOS Simulator,id=A248FB9E-B969-4CF6-A0ED-B2013A3C60A6' \
  -derivedDataPath .build/v291-native -parallel-testing-enabled NO \
  -resultBundlePath "$evidence/teach.xcresult" CODE_SIGNING_ALLOWED=NO test \
  '-only-testing:ShelfUITests/ShelfV27IntelligenceUITests/testV291TeachSupportedSubsetMixedClauseEditAndReopen' \
  2>&1 | tee "$evidence/native.log"
xcrun xcresulttool export attachments --path "$evidence/teach.xcresult" --output-path "$evidence/attachments"
