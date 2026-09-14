#!/usr/bin/env python3
"""Fail if an app Swift file references a public ShelfCore type without importing ShelfCore.

Swift imports are file-scoped. This catches the exact V18 regression where an extension file
used PassageMatch while relying on ReaderModel.swift importing ShelfCore in a different file.
"""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
core = root / "Packages" / "ShelfCore" / "Sources" / "ShelfCore"
app = root / "Shelf"
public_types: set[str] = set()

decl = re.compile(r"\bpublic\s+(?:final\s+)?(?:struct|class|enum|protocol|actor|typealias)\s+([A-Za-z_][A-Za-z0-9_]*)")
string_literal = re.compile(r'"(?:\\.|[^"\\])*"')

for path in core.rglob("*.swift"):
    for match in decl.finditer(path.read_text(encoding="utf-8")):
        public_types.add(match.group(1))

problems: list[tuple[Path, str]] = []
for path in app.rglob("*.swift"):
    text = path.read_text(encoding="utf-8")
    if "import ShelfCore" in text:
        continue
    code = string_literal.sub('""', text)
    for name in sorted(public_types):
        if re.search(rf"\b{re.escape(name)}\b", code):
            problems.append((path.relative_to(root), name))

if problems:
    for path, name in problems:
        print(f"ERROR: {path} references ShelfCore type {name} without `import ShelfCore`.")
    sys.exit(1)

print("PASS: ShelfCore file-scoped import audit.")
