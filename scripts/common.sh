#!/bin/bash
# Shared macOS/Xcode preflight. Sourcing this file does not change machine settings.
set -euo pipefail
SHELF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { printf '\nShelf: %s\n' "$*" >&2; exit 1; }

require_xcode() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "The iPhone app needs macOS and full Xcode. Core tests also run on Linux: ./scripts/test-core.sh"
  if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    local selected
    selected="$(xcode-select -p 2>/dev/null || true)"
    if [[ "$selected" == *"Xcode"*"/Contents/Developer" && -d "$selected" ]]; then
      export DEVELOPER_DIR="$selected"
    elif [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
      export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    fi
  fi
  xcrun --find xcodebuild >/dev/null 2>&1 || fail "Install full Xcode, open it once, and install an iOS Simulator runtime. Command Line Tools alone are not enough. See docs/INSTALL_ON_IPHONE.md."
  xcodebuild -version >/dev/null 2>&1 || fail "Open Xcode and complete its first-launch/license prompts, then run this command again."
  xcrun --find simctl >/dev/null 2>&1 || fail "Install the iOS platform in Xcode Settings > Components (or Platforms)."
  mkdir -p "$SHELF_ROOT/.build"
}

choose_simulator() {
  local devices
  devices="$SHELF_ROOT/.build/simulators.json"
  xcrun simctl list devices available --json > "$devices"
  SHELF_DEVICE="$(xcrun swift "$SHELF_ROOT/scripts/choose-simulator.swift" "$devices")" || \
    fail "No usable iPhone simulator. In Xcode, install an iOS 17+ simulator runtime and create an iPhone under Window > Devices and Simulators."
  [[ -n "$SHELF_DEVICE" ]] || fail "Simulator selection returned an empty identifier."
  export SHELF_DEVICE
}

boot_simulator() {
  open -a Simulator
  # simctl reports an error when an already-booted simulator is booted again.
  xcrun simctl boot "$SHELF_DEVICE" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$SHELF_DEVICE" -b
}
