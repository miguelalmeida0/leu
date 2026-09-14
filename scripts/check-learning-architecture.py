#!/usr/bin/env python3
"""Static architecture guardrails for the Shelf Learning OS domain and presentation layers."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
violations: list[str] = []

required_tokens = {
    "Packages/ShelfCore/Sources/ShelfCore/Learning/Capabilities.swift": ["protocol DocumentAnalyzing", "protocol TopicClassifying", "protocol QuestionGenerating"],
    "Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/LearningObject.swift": ["enum LearningObjectType", "struct LearningObject", "struct LearningTopic"],
    "Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/LearningSource.swift": ["struct LearningSource", "documentID", "pageIndex", "sourceText"],
    "Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/MemoryModels.swift": ["struct ReviewState", "enum RecallRating", "enum MasteryState"],
    "Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/Relationships.swift": ["struct LearningRelationship", "struct LearningTrail"],
    "Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository.swift": ["actor LearningRepository"],
    "Packages/ShelfCore/Sources/ShelfCore/Learning/Memory/ReviewScheduler.swift": ["protocol ReviewScheduling", "struct ShelfReviewScheduler"],
    "Packages/ShelfCore/Sources/ShelfCore/Learning/Questions/QuestionQualityEvaluator.swift": ["struct QuestionQualityEvaluator", "func score"],
    "Packages/ShelfCore/Sources/ShelfCore/Learning/Sessions/StudySessionPlanner.swift": ["protocol StudySessionPlanning"],
    "Shelf/Learning/Services/PDFTextExtractor.swift": ["protocol PDFTextExtracting", "actor PDFKitTextExtractor"],
    "Shelf/Learning/Services/PDFTextExtractionCheckpointStore.swift": ["protocol PDFTextExtractionCheckpointing", "FilePDFTextExtractionCheckpointStore"],
    "Shelf/Support/ShelfHaptics.swift": ["protocol HapticProviding", "enum HapticEvent"],
    "Shelf/Learning/LearnTodayScreen.swift": ["What should come back next?", "5", "10", "20", "30"],
    "Shelf/Learning/Components/PrimaryTabBar.swift": ["PrimaryArea.allCases", "primary-"],
    "Shelf/Learning/PrimaryArea.swift": ["case shelf, learn, trails"],
    "Shelf/Learning/LearningObjectActionSheet.swift": ["Remember", "Test", "Connect", "Mask", "Explain"],
}
for relative, tokens in required_tokens.items():
    path = ROOT / relative
    if not path.is_file():
        violations.append(f"missing architecture component: {relative}")
        continue
    text = path.read_text(errors="replace")
    for token in tokens:
        if token not in text:
            violations.append(f"{relative}: missing required contract token {token!r}")

# New learning UI should stay modular. The deterministic question generator is split into two cohesive files.
for path in (ROOT / "Shelf/Learning").rglob("*.swift"):
    lines = len(path.read_text(errors="replace").splitlines())
    if lines > 250:
        violations.append(f"{path.relative_to(ROOT)}: Learning UI file exceeds 250-line scrutiny boundary ({lines})")
for path in (ROOT / "Packages/ShelfCore/Sources/ShelfCore/Learning").rglob("*.swift"):
    lines = len(path.read_text(errors="replace").splitlines())
    if lines > 250:
        violations.append(f"{path.relative_to(ROOT)}: Learning core file exceeds 250-line scrutiny boundary ({lines})")

# No superficial reward mechanics should leak into production learning UI copy.
for path in (ROOT / "Shelf/Learning").rglob("*.swift"):
    text = path.read_text(errors="replace")
    # Match actual reward nouns/phrases, not substrings in identifiers like "strip".
    if re.search(r'(?i)\b(xp|streaks?|coins?|badges?|leaderboards?|confetti|daily quests?)\b', text):
        violations.append(f"{path.relative_to(ROOT)}: superficial gamification term found")

if violations:
    print("FAIL: Learning OS architecture contract")
    for violation in violations:
        print(" -", violation)
    sys.exit(1)
print("PASS: Learning OS domain/services/UI boundaries, modularity, haptic protocol, and calm-product guardrails are present.")
