#!/bin/bash
# Pure Swift domain, import, persistence, search, integrity, and backup tests.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v swift >/dev/null 2>&1 || { printf 'Install Swift 5.9+ or Xcode first.\n' >&2; exit 1; }
exec swift test --package-path "$ROOT/Packages/ShelfCore" --jobs "${SHELF_TEST_JOBS:-4}" "$@"
