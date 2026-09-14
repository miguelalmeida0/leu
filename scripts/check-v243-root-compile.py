#!/usr/bin/env python3
"""Narrow source policy for this repair; not a Swift parser or Apple typecheck."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
ROOT_VIEW = 'Shelf/App/RootView.swift'
READ_PAGE = 'Shelf/Features/Reader/Components/ReadPageContent.swift'
SEARCH = 'Shelf/Features/Reader/ReaderSearchSheet.swift'
VIEW_MEMBERS = ('body', 'rootContent', 'bottomChrome', 'lifecycleContent',
                'readerAndSheetPresentation', 'backupPresentation')
LIFECYCLE = ('bootstrapOnLaunch', 'restoreStudyOnLaunchIfNeeded', 'retryBootstrap',
             'synchronizeLibraryIndexes', 'scenePhaseChanged', 'primaryAreaChanged',
             'activeSessionChanged', 'knowledgeDestinationChanged', 'readerDidDismiss',
             'backupImportCompleted', 'mergeBackup', 'openKnowledgeDestination', 'resetLibraryScope')


def member(source: str, marker: str) -> str:
    """Extract a known braced member, ignoring ordinary string/comment braces."""
    masked = re.sub(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/',
                    lambda m: re.sub(r'[^\n]', ' ', m.group()), source)
    begin = masked.find(marker)
    if begin < 0:
        raise ValueError('Missing member: ' + marker)
    opening = masked.index('{', begin)
    depth = 1
    for end in range(opening + 1, len(masked)):
        if masked[end] == '{': depth += 1
        elif masked[end] == '}': depth -= 1
        if depth == 0:
            return source[begin:end + 1]
    raise ValueError('Unbalanced member: ' + marker)


def violations(overrides=None):
    overrides = overrides or {}
    def read(path): return overrides.get(path, (ROOT / path).read_text())
    root, page, search = read(ROOT_VIEW), read(READ_PAGE), read(SEARCH)
    errors = []
    for name in VIEW_MEMBERS:
        try:
            expression = member(root, 'var ' + name + ': some View')
        except ValueError as error:
            errors.append(str(error)); continue
        if len(expression.splitlines()) > 35:
            errors.append(name + ': split oversized view expressions')
        if re.search(r'await\s+(?:container\.|model\.)', expression):
            errors.append(name + ': model lifecycle belongs in typed methods')
    for name in LIFECYCLE:
        try: member(root, 'private func ' + name + '(')
        except ValueError as error: errors.append(str(error))
    for token in ('AnyView(', '@unchecked Sendable', 'nonisolated(unsafe)',
                  'learningStatePresented'):
        if token in root: errors.append('Forbidden workaround: ' + token)
    required = ('@State private var studySurface: StudySurface = .landing',
                '@Environment(\\.scenePhase)', 'private var activeBookVersions: [String]',
                '.task { await bootstrapOnLaunch() }', 'case .progress:',
                'LearningStateSheet(model: container.learning)',
                'restoreLens: destination.restoreLens',
                '.onChange(of: container.learning.activeSession?.id)',
                '.onChange(of: container.knowledge.pendingDestination)',
                'StudyInteractionTrace.record("route.session.requested")')
    for token in required:
        if token not in root: errors.append('Missing preserved behavior: ' + token)
    try:
        boot = member(root, 'private func bootstrapOnLaunch(')
        sequence = ('await container.library.bootstrap()', 'await container.learning.bootstrap()',
                    'restoreStudyOnLaunchIfNeeded()', 'await container.knowledge.bootstrap()')
        locations = [boot.find(token) for token in sequence]
        if -1 in locations or locations != sorted(locations):
            errors.append('Launch order must remain library, learning, restore, knowledge')
        restore = member(root, 'private func restoreStudyOnLaunchIfNeeded(')
        for token in ('container.learning.isReady', '!didRestoreStudyOnLaunch',
                      'didRestoreStudyOnLaunch = true', 'session.completedAt == nil',
                      'primaryArea = .learn', 'studySurface = .landing'):
            if token not in restore: errors.append('Missing launch guard/state: ' + token)
        sync = member(root, 'private func synchronizeLibraryIndexes(')
        if sync.find('await container.learning.syncLibrary()') < 0 or \
           sync.find('await container.knowledge.syncLibrary()') < sync.find('await container.learning.syncLibrary()'):
            errors.append('Index sync order must remain learning then knowledge')
    except ValueError as error:
        errors.append(str(error))
    for label, source, expected in (('reading highlight', page, 2), ('search highlight', search, 3)):
        if re.search(r'\[range\]\.(?:backgroundColor|foregroundColor|font)\s*=', source):
            errors.append(label + ': avoid dynamically inferred attribute key paths')
        if source.count('[range][AttributeScopes.SwiftUIAttributes.') != expected:
            errors.append(label + ': preserve explicit typed attribute assignments')
    return errors


if __name__ == '__main__':
    failures = violations()
    if failures:
        print('\n'.join('FAIL: ' + failure for failure in failures))
        sys.exit(1)
    print('PASS: bounded RootView expressions, typed lifecycle callbacks, preserved route ownership and explicit highlight keys')
