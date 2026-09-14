#!/usr/bin/env python3
"""Mutation checks + execution of actual RootView handlers with portable adapters.
No SwiftUI, PDFKit, ONNX or Apple SDK is provided by these tests.
"""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('root_policy', ROOT / 'scripts/check-v243-root-compile.py')
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


class RootCompileRepairTests(unittest.TestCase):
    def mutate(self, path, old, new):
        text = (ROOT / path).read_text()
        self.assertIn(old, text)
        self.assertTrue(policy.violations({path: text.replace(old, new)}))

    def testCurrentSource(self):
        self.assertEqual(policy.violations(), [])

    def testOversizedBodyIsRejected(self):
        self.mutate(policy.ROOT_VIEW, 'var body: some View {',
                    'var body: some View {\n' + ' // more inline expression work\n' * 40)

    def testModelLifecycleCannotReturnToBuilder(self):
        self.mutate(policy.ROOT_VIEW, '.task { await bootstrapOnLaunch() }',
                    '.task { await container.library.bootstrap() }')

    def testMissingTypedBookIdentityIsRejected(self):
        self.mutate(policy.ROOT_VIEW, 'private var activeBookVersions: [String]',
                    'private var activeBookVersions: ArraySlice<String>')

    def testLaunchOrderMustStayTheSame(self):
        self.mutate(policy.ROOT_VIEW, 'await container.library.bootstrap()\n        await container.learning.bootstrap()',
                    'await container.learning.bootstrap()\n        await container.library.bootstrap()')

    def testRecoveryMustWaitForReadiness(self):
        self.mutate(policy.ROOT_VIEW, 'guard container.learning.isReady, !didRestoreStudyOnLaunch',
                    'guard !didRestoreStudyOnLaunch')

    def testRecoveryMustRunOnlyOnce(self):
        self.mutate(policy.ROOT_VIEW, '!didRestoreStudyOnLaunch', 'true')

    def testCompletedSessionMustNotRestore(self):
        self.mutate(policy.ROOT_VIEW, 'session.completedAt == nil', 'true')

    def testLensOriginMustNotBeDropped(self):
        self.mutate(policy.ROOT_VIEW, 'restoreLens: destination.restoreLens', 'restoreLens: nil')

    def testTypeErasureIsNotACompileRepair(self):
        self.mutate(policy.ROOT_VIEW, '        backupPresentation\n', '        AnyView(backupPresentation)\n')

    def testDynamicReadingAttributesAreRejected(self):
        self.mutate(policy.READ_PAGE, '[range][AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self]',
                    '[range].backgroundColor')

    def testDynamicSearchFontIsRejected(self):
        self.mutate(policy.SEARCH, '[range][AttributeScopes.SwiftUIAttributes.FontAttribute.self]', '[range].font')

    def testActualLifecycleMethodBodies(self):
        swiftc = shutil.which('swiftc')
        self.assertIsNotNone(swiftc, 'Swift compiler required; this test must not silently skip')
        source = (ROOT / policy.ROOT_VIEW).read_text()
        methods = [policy.member(source, 'private func ' + name + '(').replace('private func', 'func', 1)
                   for name in policy.LIFECYCLE]
        versions = policy.member(source, 'var activeBookVersions: [String]')
        generated = '''import Foundation
@MainActor struct RootLogicProbe {
    let container = AppContainer()
    @RootTestState var didRestoreStudyOnLaunch = false
    @RootTestState var primaryArea: PrimaryArea = .shelf
    @RootTestState var studySurface: StudySurface = .landing
''' + '\n'.join(methods) + '\n' + versions + '\n}\n'
        with tempfile.TemporaryDirectory(prefix='leu-root-v243-') as temp:
            temp = Path(temp)
            extracted = temp / 'RootLogicProbe.swift'
            extracted.write_text(generated)
            executable = temp / 'root-handlers'
            result = subprocess.run([swiftc, '-swift-version', '5', '-strict-concurrency=complete',
                '-warnings-as-errors', '-parse-as-library', str(extracted),
                str(ROOT / 'Shelf/Learning/PrimaryArea.swift'),
                str(ROOT / 'validation/v24-3/RootDependencies.swift'),
                str(ROOT / 'validation/v24-3/RootHarness.swift'), '-o', str(executable)],
                capture_output=True, text=True, timeout=120)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            run = subprocess.run([str(executable)], capture_output=True, text=True, timeout=30)
            print(run.stdout, end='')
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertIn('extracted RootView lifecycle checks', run.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)
