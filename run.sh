#!/bin/bash
# One command: build, install, and open Shelf in an available iPhone simulator.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-}" in
  --help|-h)
    printf '%s\n' 'Shelf — native iPhone PDF library' '' \
      './run.sh           Build and launch in the iPhone simulator.' \
      './run.sh --xcode   Open the project for installation on your own iPhone.' \
      './run.sh --build   Compile for the simulator without launching.' '' \
      'Requires a Mac, full Xcode 16+, and an iOS 17+ simulator runtime.' \
      'No npm, CocoaPods, API keys, project generators, or external Swift packages.'
    exit 0 ;;
  ""|--xcode|--build) ;;
  *) printf 'Unknown option: %s. Use ./run.sh --help\n' "$1" >&2; exit 2 ;;
esac
source "$ROOT/scripts/common.sh"
require_xcode
if [[ "${1:-}" == "--xcode" ]]; then
  open "$ROOT/Shelf.xcodeproj"
  printf '\nSelect the Shelf target, your Signing Team, and your iPhone; press Command-R.\n'
  exit 0
fi
if [[ "${1:-}" == "--build" ]]; then
  xcodebuild -project "$ROOT/Shelf.xcodeproj" -scheme Shelf -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$ROOT/.build/ios" \
    CODE_SIGNING_ALLOWED=NO build
  exit 0
fi
choose_simulator
boot_simulator
printf '\nBuilding Shelf. The first build may take several minutes.\n'
xcodebuild -project "$ROOT/Shelf.xcodeproj" -scheme Shelf -configuration Debug \
  -destination "platform=iOS Simulator,id=$SHELF_DEVICE" -derivedDataPath "$ROOT/.build/ios" \
  CODE_SIGNING_ALLOWED=NO build
APP="$ROOT/.build/ios/Build/Products/Debug-iphonesimulator/Shelf.app"
[[ -d "$APP" ]] || fail "Build finished without the expected Shelf.app. See the xcodebuild output above."
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")"
xcrun simctl install "$SHELF_DEVICE" "$APP"
xcrun simctl launch --terminate-running-process "$SHELF_DEVICE" "$BUNDLE_ID"
printf '\nShelf is open in Simulator. For your physical iPhone: ./run.sh --xcode\n'
