#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
printf '\n=== Leu V24.5 structural validation ===\n'; python3 scripts/validate.py
printf '\n=== Leu file-scoped import audit ===\n'; python3 scripts/check-shelfcore-imports.py
printf '\n=== Leu Learning OS offline/no-model audit ===\n'; python3 scripts/check-learning-offline.py
printf '\n=== Leu Learning OS architecture audit ===\n'; python3 scripts/check-learning-architecture.py
printf '\n=== Leu Connected Knowledge architecture audit ===\n'; python3 scripts/check-connected-architecture.py
printf '\n=== Leu Voice architecture audit ===\n'; python3 scripts/check-voice-architecture.py
printf '\n=== Leu Connected Knowledge + Voice privacy boundary ===\n'; python3 scripts/check-worldclass-offline.py
printf '\n=== Leu V24 semantic/emotional/neural release contract ===\n'; python3 scripts/check-v24-contract.py
printf '\n=== Leu native UI test contract audit ===\n'; python3 scripts/check-ui-test-contract.py; python3 scripts/check-study-interactions.py; python3 scripts/test-study-repair-tools.py
printf '\n=== Leu SwiftUI compile-contract audit ===\n'; python3 scripts/check-swiftui-compile-contract.py; python3 scripts/test-settings-compile-repair.py
printf '\n=== Leu Night Field design contract ===\n'; python3 scripts/check-night-field.py
printf '\n=== Leu V24.2 interaction and recovery source contracts ===\n'; python3 scripts/check-v242-interactions.py; python3 scripts/test-v242-interactions.py
printf '\n=== Leu V24.3 root compile source checks ===\n'; python3 scripts/check-v243-root-compile.py; python3 scripts/test-v243-root-compile.py
printf '\n=== Leu V24.4 Lens compile source checks ===\n'; python3 scripts/check-v244-lens-compile.py; python3 scripts/test-v244-lens-compile.py
printf '\n=== Leu V24.5 Release interaction and complete-suite checks ===\n'; python3 scripts/check-v245-release.py; python3 scripts/test-v245-release.py
printf '\n=== Leu native compile gate ===\n'; ./run.sh --build
python3 scripts/run-qa-suites.py
