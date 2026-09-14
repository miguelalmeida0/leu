#!/usr/bin/env python3
"""Narrow regression policies for the Release gesture/viewport boundary, not native certification."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SUMMARY = 'Shelf/Learning/SessionCompleteView.swift'
RELEASE = 'Shelf/Learning/Components/ReleaseSurface.swift'
STATE = 'Shelf/Learning/ReleaseInteractionState.swift'
HELPER = 'ShelfUITests/ReleaseInteractionSupport.swift'


def member(text, marker):
    start = text.index(marker)
    opening = text.index('{', start)
    depth, end = 1, opening + 1
    while depth and end < len(text):
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    if depth:
        raise ValueError('Unclosed member: ' + marker)
    return text[start:end]


def violations(overrides=None):
    overrides = overrides or {}
    def read(path): return overrides.get(path, (ROOT / path).read_text())
    summary, release, state, helper = [read(path) for path in [SUMMARY, RELEASE, STATE, HELPER]]
    issues = []
    summary_content = member(summary, 'private var summaryContent:')
    if 'ReleaseSurface(' in summary_content or 'Canvas' in summary_content:
        issues.append('Do not embed the drawing surface inside the scrolling summary.')
    body = member(summary, 'var body: some View')
    if 'if model.releasePresented' not in body or 'ReleaseSurface(' not in body or 'else' not in body:
        issues.append('Release and the summary must be mutually exclusive surfaces.')
    for token in ['.safeAreaInset(edge: .bottom, spacing: 0) { controls }',
                  'minHeight: 44', '.padding(.bottom, 16)', 'dynamicTypeSize.isAccessibilitySize',
                  'release-accessible-action', 'release-continue', 'release-done',
                  'release-completed-message', 'UITestFrameProbe(identifier: "release-surface")']:
        if token not in release: issues.append('Missing Release boundary: ' + token)
    controls = member(release, 'private var controls:')
    if 'Canvas' in controls or '.gesture(' in controls:
        issues.append('Pinned actions must not be inside the drawing gesture.')
    for token in ['AnyView(', '.accessibilityElement(children: .ignore)', '.highPriorityGesture(']:
        if token in release: issues.append('Unsafe Release workaround: ' + token)
    if 'private func savePlaceAndEnd' in summary or 'try? await model.repository.saveResumeStudyContext' in summary:
        issues.append('Completion exit must not create an unordered, swallowed resume write.')
    for token in ['model.persistStudyState()', 'await model.studySaveTask?.value', 'guard model.studySaveError == nil']:
        if token not in member(summary, 'private func finishSession('):
            issues.append('Completion exit must await a successful checkpoint: ' + token)
    for token in ['maximumPoints = 2_048', 'maximumStrokes = 64', 'phase != .released',
                  'point.x.isFinite', 'point.y.isFinite', 'strokes.removeAll(keepingCapacity: false)']:
        if token not in state: issues.append('Missing bounded ephemeral-state invariant: ' + token)
    if 'dragStudyViewport(' in helper or 'coordinate(withNormalizedOffset:' in helper:
        issues.append('Pinned-control acceptance must not scroll around the defect.')
    for token in ['studyViewport(probe).contains(button.frame)', 'query.count == 1',
                  'button.isEnabled && button.isHittable', 'app.buttons[identifier].tap()']:
        if token not in helper: issues.append('Pinned acceptance must verify real full-size controls: ' + token)
    return issues


if __name__ == '__main__':
    issues = violations()
    if issues:
        print('FAIL: Release interaction source policy\n' + '\n'.join(issues))
        sys.exit(1)
    print('PASS: isolated Release surface, pinned native actions, bounded ephemeral drawing and acknowledged exit')
