#!/usr/bin/env python3
"""Fail if Shelf Learning OS gains a network, model-inference, camera, or external-package dependency."""
from pathlib import Path
import plistlib
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
violations: list[str] = []

package = (ROOT / "Packages/ShelfCore/Package.swift").read_text()
if ".package(url:" in package or ".package(path:" in package:
    # ShelfCore is intentionally dependency-free. Local app package linkage is handled by Xcode.
    violations.append("Packages/ShelfCore/Package.swift: Learning core must remain dependency-free")

swift_roots = [ROOT / "Shelf/Learning", ROOT / "Packages/ShelfCore/Sources/ShelfCore/Learning"]
patterns = {
    r"^\s*import\s+Vision\b": "Vision/model inference is not permitted in this release",
    r"^\s*import\s+CoreML\b": "CoreML/model inference is not permitted in this release",
    r"^\s*import\s+Network\b": "Network framework is not required by offline Learning OS",
    r"\bURLSession\b": "URLSession/network access is not permitted for studying",
    r"\bNWConnection\b": "Network connection is not permitted for studying",
    r"\bWKWebView\b": "web-backed study surfaces are not permitted",
    r"\b(OpenAI|Anthropic|Gemini|ChatGPT)\b": "external generative-AI dependency/reference detected in Swift source",
}
for base in swift_roots:
    for path in base.rglob("*.swift"):
        text = path.read_text(errors="replace")
        for pattern, reason in patterns.items():
            if re.search(pattern, text, flags=re.MULTILINE):
                violations.append(f"{path.relative_to(ROOT)}: {reason}")

info_path = ROOT / "Shelf/Resources/Info.plist"
info = plistlib.loads(info_path.read_bytes())
if "NSCameraUsageDescription" in info:
    violations.append("Shelf/Resources/Info.plist: camera permission must not be requested by this deterministic release")
if not str(info.get("NSMicrophoneUsageDescription", "")).strip():
    violations.append("Shelf/Resources/Info.plist: explicit microphone explanation is required for local Explain recordings")

required = [
    "Packages/ShelfCore/Sources/ShelfCore/Learning/Questions/DeterministicQuestionEngine.swift",
    "Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningSnapshotPersistence.swift",
    "Shelf/Learning/Services/PDFLearningIndexer.swift",
    "Shelf/Learning/Services/ExplanationRecorder.swift",
]
for relative in required:
    if not (ROOT / relative).is_file():
        violations.append(f"missing offline Learning OS component: {relative}")

if violations:
    print("FAIL: Learning OS on-device learning privacy contract")
    for violation in violations:
        print(" -", violation)
    sys.exit(1)
print("PASS: Learning remains local; Apple Foundation Models is allowed, with no network, camera or external AI client in study code.")
