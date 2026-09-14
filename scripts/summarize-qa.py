#!/usr/bin/env python3
"""Summarize the complete log, retaining early compiler errors and failure-only trees."""
import re
import sys
from pathlib import Path

if len(sys.argv) != 2 or not Path(sys.argv[1]).is_file():
    raise SystemExit("Usage: python3 scripts/summarize-qa.py <existing-log>")
patterns = [
    r"^===", r"^PASS:", r"^FAIL:", r"^NOT CHECKED:",
    r"\*\* (?:BUILD|TEST) (?:SUCCEEDED|FAILED) \*\*",
    r"Test Case .*Shelf(?:UI|Reader|Interaction).*\b(?:passed|failed|skipped) \(",
    r"Executed \d+ tests, with \d+ failures",
    r"(?:^|\s)(?:error:|fatal error:)", r"^Testing (?:failed|cancelled)",
    r"^xcodebuild: error:", r"^Test result:", r"^Test session results,", r"^QA complete",
    r"^QA_STAGE_RESULT:", r"^LEU_UI_CHECKPOINT:", r"^Shelf:", r"Structural validation failed:",
    r"^The following build commands failed:",
]
match = re.compile("|".join(patterns))
outcome = re.compile(r"^Test Case .* (passed|failed|skipped) \(")
lines = [re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", line).strip()
         for line in Path(sys.argv[1]).read_text(errors="replace").splitlines()]
diagnostic = re.compile(r"(?:^|\s)(?:error:|fatal error:)")
context_lines: set[int] = set()
for index, line in enumerate(lines):
    if diagnostic.search(line):
        # An error may occur thousands of lines before the final build banner.
        # Keep the source excerpt, caret and overload notes as well as the error.
        context_lines.update(range(max(0, index - 2), min(len(lines), index + 5)))
    if line.startswith("The following build commands failed:"):
        context_lines.update(range(index, min(len(lines), index + 6)))
previous = None
in_tree = False
pending_trees: list[str] = []


def emit_trees() -> None:
    if len(pending_trees) > 220:
        print("\n".join(pending_trees[:220]))
        print("[Tree shortened in clipboard; complete trees remain in the full log and diagnostics bundle.]")
    else:
        print("\n".join(pending_trees))


for index, line in enumerate(lines):
    if line.startswith("LEU_UI_TREE_BEGIN:"):
        in_tree = True
    if in_tree:
        pending_trees.append(line)
        if line.startswith("LEU_UI_TREE_END:"):
            in_tree = False
        continue
    result = outcome.search(line)
    if result:
        if result.group(1) != "passed" and pending_trees:
            emit_trees()
        pending_trees.clear()
    if (match.search(line) or index in context_lines) and line != previous:
        print(line)
        previous = line
# A crashed/interrupted runner may never emit an outcome; retain those diagnostics.
if pending_trees:
    emit_trees()

if any("** BUILD FAILED **" in line for line in lines) and not any(
    re.search(r"(?:^|\s)(?:error:|fatal error:)", line) for line in lines
):
    print("FAIL: Build failed without a captured compiler error diagnostic. Share the complete log; a tail alone is insufficient.")

warning_counts: dict[str, int] = {}
for line in lines:
    if ": warning:" in line:
        warning = line.split(": warning:", 1)[1].strip()
        warning_counts[warning] = warning_counts.get(warning, 0) + 1
if warning_counts:
    print("=== Distinct compiler warnings (full context in log) ===")
    for warning, count in warning_counts.items():
        print(f"WARNING ({count} occurrence(s)): {warning}")
