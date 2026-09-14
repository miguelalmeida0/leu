#!/usr/bin/env python3
"""Bounded Lens expressions and unchanged source-navigation contract; not Apple compilation."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SHEET = 'Shelf/Learning/UnderstandingLensSheet.swift'
ROW = 'Shelf/Learning/Components/UnderstandingLensFactRow.swift'
FACT = 'Shelf/Learning/UnderstandingLensFact.swift'
RECORDER = 'Shelf/Learning/Services/ExplanationRecorder.swift'


def member(source, marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth = 1
    index = opening + 1
    while depth and index < len(source):
        depth += (source[index] == '{') - (source[index] == '}')
        index += 1
    if depth:
        raise ValueError('Unclosed source member: ' + marker)
    return source[start:index]


def violations(overrides=None):
    overrides = overrides or {}
    def read(path):
        return overrides.get(path, (ROOT / path).read_text())
    sheet, row, fact, recorder = [read(p) for p in (SHEET, ROW, FACT, RECORDER)]
    issues = []
    for name, text in [(SHEET, sheet), (ROW, row)]:
        if 'AnyView(' in text or '.accessibilityElement(children: .ignore)' in text:
            issues.append(name + ': type erasure/semantic replacement is not the repair')
        for match in re.finditer(r'(?:private )?var \w+: some View', text):
            if len(member(text, match.group()).splitlines()) > 18:
                issues.append(name + ': view expression exceeds the 18-line source bound')
        if 'item.proposition.' in text or '\\.proposition.id' in text:
            issues.append(name + ': tuple/deep semantic expressions returned to ViewBuilder')
    for token in ['struct UnderstandingLensFact: Identifiable', 'let accessibilityValue: String',
                  'let target: LearningSource', 'guard proposition.isQuizTruth',
                  'semanticIndexes.values', 'rows.sort(by: orderedBefore)', 'rows.prefix(24)',
                  'target = evidence.learningSource']:
        if token not in fact:
            issues.append('Lens projection contract missing: ' + token)
    for token in ['ForEach(rows)', '(fact: UnderstandingLensFact)',
                  'queueLensNavigation(to: target, from: source)',
                  'UITestFrameProbe(identifier: "understanding-lens")', 'Nothing is generated to fill the gap.']:
        if token not in sheet:
            issues.append('Lens sheet contract missing: ' + token)
    for token in ['Button(action: selectSource)', 'onSelect(fact.target)',
                  '.accessibilityValue(Text(verbatim: fact.accessibilityValue))',
                  '.accessibilityLabel(Text(verbatim: fact.accessibilityLabel))',
                  '.accessibilityIdentifier(fact.accessibilityIdentifier)', '.contentShape(Rectangle())']:
        if token not in row:
            issues.append('Native Lens row contract missing: ' + token)
    if 'AVAudioSession.sharedInstance().requestRecordPermission' in recorder:
        issues.append('Deprecated microphone permission API returned')
    if 'AVAudioApplication.requestRecordPermission' not in recorder:
        issues.append('iOS 17 microphone permission API missing')
    return issues


if __name__ == '__main__':
    errors = violations()
    if errors:
        print('FAIL: V24.4 Lens source checks\n' + '\n'.join(errors))
        sys.exit(1)
    print('PASS: nominal Lens rows, bounded expressions, explicit accessibility Text and preserved source action')
