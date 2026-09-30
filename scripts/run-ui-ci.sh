#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAX_ATTEMPTS="${LEU_UI_CI_MAX_ATTEMPTS:-2}"
attempt=1

is_infrastructure_failure() {
  local log="$1"
  grep -Eqi \
    'Early unexpected exit|operation never finished bootstrapping|Failed to get list of active applications|XC_kAXXCAttributeFocusedApplications|Timed out while fetching attributes|Timed out while evaluating UI query|Timed out while requesting screenshot|Failed to get matching snapshots: Timed out|Failed to get matching snapshot: Timed out' \
    "$log"
}

while (( attempt <= MAX_ATTEMPTS )); do
  log="$ROOT/.build/ui-ci-attempt-${attempt}-$$.log"
  mkdir -p "$ROOT/.build"

  echo "::group::Apple UI attempt $attempt/$MAX_ATTEMPTS"
  set +e
  "$ROOT/scripts/test-ios.sh" \
    -retry-tests-on-failure \
    -test-iterations 2 \
    "$@" 2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
  set -e
  echo "::endgroup::"

  if (( status == 0 )); then
    echo "Apple UI shard passed on attempt $attempt."
    exit 0
  fi

  if (( attempt < MAX_ATTEMPTS )) && is_infrastructure_failure "$log"; then
    echo "::warning::Transient XCUITest/Simulator infrastructure failure detected. Resetting Simulator and retrying the shard once."
    xcrun simctl shutdown all >/dev/null 2>&1 || true
    killall Simulator >/dev/null 2>&1 || true
    sleep 5
    attempt=$((attempt + 1))
    continue
  fi

  echo "Apple UI shard failed with a non-transient failure, or retry budget was exhausted."
  exit "$status"
done
