#!/bin/bash
# Typecheck the real annotated app model. Then execute its unchanged method bodies
# with Observation/PDF/UI adapters excluded. Neither check certifies SwiftUI rendering.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="$ROOT/Packages/ShelfCore"
swift build --package-path "$PACKAGE" --jobs 4 >/dev/null
BIN="$(swift build --package-path "$PACKAGE" --show-bin-path)"
OUT="$ROOT/.build/v24-model-checks"
mkdir -p "$OUT/logic"
SOURCES=("$ROOT/Shelf/Learning/LearningModel.swift"
    "$ROOT/Shelf/Learning/LearningModel+Sessions.swift"
    "$ROOT/Shelf/Learning/LearningModel+Recovery.swift"
    "$ROOT/validation/v24-2/RecoveryDependencies.swift"
    "$ROOT/validation/v24-2/RecoveryHarness.swift")
swiftc -swift-version 5 -strict-concurrency=complete -parse-as-library -typecheck \
    -I "$BIN/Modules" "${SOURCES[@]}"
printf 'PASS: actual Observation-annotated LearningModel typechecked with complete concurrency checking\n'
# This environment's libswiftObservation.so has an unresolved runtime symbol.
# Do not patch the runtime or fake that framework. Test pure state/persistence logic
# separately, leaving method bodies, MainActor isolation and production source intact.
python3 - "$OUT/logic" "${SOURCES[@]}" <<'PY'
from pathlib import Path
import sys
out=Path(sys.argv[1])
for source in map(Path,sys.argv[2:]):
    text=source.read_text().replace('import Observation\n','').replace('@Observable','').replace('@ObservationIgnored','')
    (out/source.name).write_text(text)
PY
swiftc -swift-version 5 -strict-concurrency=complete -parse-as-library \
    -I "$BIN/Modules" "$BIN"/ShelfCore.build/*.swift.o "$OUT"/logic/*.swift -o "$OUT/recovery-check"
"$OUT/recovery-check"
