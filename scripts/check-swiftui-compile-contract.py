#!/usr/bin/env python3
from pathlib import Path
import re, sys
from swiftui_section_contract import check as check_sections
root = Path(__file__).resolve().parents[1]
failures=check_sections(root)

# Known illegal SwiftUI fixed-frame overload: frame(width:, minHeight:)
for p in (root/'Shelf').rglob('*.swift'):
    text=p.read_text(errors='ignore')
    for n,line in enumerate(text.splitlines(),1):
        if re.search(r'\.frame\([^)]*(?:width|height)\s*:[^)]*min(?:Width|Height)\s*:', line):
            failures.append(f'{p.relative_to(root)}:{n}: invalid fixed frame overload')

# Type namespace regression from V21.0
for p in (root/'Shelf').rglob('*.swift'):
    text=p.read_text(errors='ignore')
    for n,line in enumerate(text.splitlines(),1):
        if 'LearningTokens.Type' in line:
            failures.append(f'{p.relative_to(root)}:{n}: LearningTokens.Type is illegal; use Typography')

# Result-builder early return regression in the exact study activity surface.
p=root/'Shelf/Learning/StudySessionScreen.swift'
text=p.read_text(errors='ignore')
if '@ViewBuilder' in text and re.search(r'private var activityBody: some View\s*\{[\s\S]*?guard\s+let[\s\S]*?\n\s*return\s*\n', text):
    failures.append('Shelf/Learning/StudySessionScreen.swift: @ViewBuilder activityBody contains early return')

# navigationDestination(item:) requires its item to be Hashable.
rel=(root/'Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/Relationships.swift').read_text(errors='ignore')
if '.navigationDestination(item:' in (root/'Shelf/Learning/TrailsScreen.swift').read_text(errors='ignore'):
    if not re.search(r'public struct LearningTrail:[^\n]*\bHashable\b', rel):
        failures.append('LearningTrail must conform to Hashable for navigationDestination(item:)')


# Detached tasks must not reach back through MainActor-isolated KnowledgeModel state.
km = (root/'Shelf/Knowledge/KnowledgeModel.swift').read_text(errors='ignore')
if 'Task.detached' in km:
    if 'let pipeline = self.pipeline' not in km:
        failures.append('Shelf/Knowledge/KnowledgeModel.swift: capture Sendable pipeline locally before Task.detached')
    if re.search(r'Task\.detached[\s\S]{0,300}?self\.pipeline\.index', km):
        failures.append('Shelf/Knowledge/KnowledgeModel.swift: detached task directly captures MainActor self.pipeline')

if failures:
    print('FAIL: SwiftUI compile-contract audit')
    for f in failures: print(' -', f)
    sys.exit(1)
print('PASS: SwiftUI compile-contract audit (result builders, Hashable navigation items, frame overloads, token namespace, actor-safe detached captures, Section overloads).')
