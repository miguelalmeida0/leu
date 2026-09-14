#!/usr/bin/env python3
"""Compile/run the real Lens projection with real core types, plus source mutation checks.
Routing action adapters are NOT an Apple UI test. All native tests remain mandatory.
"""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('lens_policy', ROOT / 'scripts/check-v244-lens-compile.py')
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


class LensCompileRepairTests(unittest.TestCase):
    def mutate(self, path, old, new):
        text = (ROOT / path).read_text()
        self.assertIn(old, text)
        self.assertTrue(policy.violations({path: text.replace(old, new)}))

    def testCurrentSource(self):
        self.assertEqual(policy.violations(), [])

    def testLargeBuilderRejected(self):
        self.mutate(policy.SHEET, 'var body: some View {',
                    'var body: some View {\n' + ' // extra builder work\n' * 30)

    def testGenericTupleIdentityRejected(self):
        self.mutate(policy.SHEET, 'ForEach(rows)', 'ForEach(rows, id: \\.proposition.id)')

    def testAccessibilityValueIsExplicitText(self):
        self.mutate(policy.ROW, '.accessibilityValue(Text(verbatim: fact.accessibilityValue))',
                    '.accessibilityValue("Page \\(item.proposition.evidence.pageIndex + 1)")')

    def testNativeButtonCannotBecomeIgnoredContainer(self):
        self.mutate(policy.ROW, '.buttonStyle(.plain)',
                    '.buttonStyle(.plain).accessibilityElement(children: .ignore)')

    def testFactFilterMustRemain(self):
        self.mutate(policy.FACT, 'guard proposition.isQuizTruth', 'guard true')

    def testSourceProjectionMustRemain(self):
        self.mutate(policy.FACT, 'target = evidence.learningSource', 'target = origin')

    def testRowCapMustRemain(self):
        self.mutate(policy.FACT, 'rows.prefix(24)', 'rows.prefix(1000)')

    def testSourceOriginMustRemain(self):
        self.mutate(policy.SHEET, 'queueLensNavigation(to: target, from: source)',
                    'queueLensNavigation(to: target, from: target)')

    def testDeprecatedPermissionAPIRejected(self):
        self.mutate(policy.RECORDER, 'AVAudioApplication.requestRecordPermission',
                    'AVAudioSession.sharedInstance().requestRecordPermission')

    def testRealProjectionAndSourceActionBodies(self):
        swiftc = shutil.which('swiftc')
        self.assertIsNotNone(swiftc, 'Swift compiler is required; no silent skip')
        source = (ROOT / policy.SHEET).read_text()
        route = policy.member(source, 'private func showSource(').replace('private func', 'func', 1)
        row = policy.member((ROOT / policy.ROW).read_text(), 'private func selectSource(')
        row = row.replace('private func', 'func', 1)
        generated = '''import ShelfCore
@MainActor struct LensRouteProbe {
    let reader: LensReaderProbe
    let source: LearningSource
    let dismiss: LensDismissProbe
''' + route + '''
}
@MainActor struct LensRowActionProbe {
    let fact: UnderstandingLensFact
    let onSelect: @MainActor (LearningSource) -> Void
''' + row + '\n}\n'
        core = ROOT / 'Packages/ShelfCore/Sources/ShelfCore'
        with tempfile.TemporaryDirectory(prefix='leu-lens-v244-') as temp:
            temp = Path(temp)
            # Unmodified production definitions only; no substitute semantic models.
            definitions = [core / 'Learning/Domain/LearningSource.swift',
                           core / 'Learning/Analysis/StableIdentity.swift',
                           core / 'Learning/Semantic/SemanticModels.swift',
                           core / 'Learning/Semantic/GeneralClaimExtractor.swift',
                           core / 'Learning/Semantic/TradeoffExtractor.swift',
                           core / 'Learning/Semantic/QuestionRealizer.swift']
            objects = []
            for file in definitions:
                output = temp / (file.stem + '.o')
                # Each compilation sees the complete set of production type declarations.
                objects.append(output)
            output_map = {str(file): {'object': str(obj)} for file, obj in zip(definitions, objects)}
            import json
            mapping = temp / 'outputs.json'
            mapping.write_text(json.dumps(output_map))
            flags = ['-swift-version', '5', '-strict-concurrency=complete', '-warnings-as-errors']
            build = subprocess.run([swiftc, *flags, '-parse-as-library', '-module-name', 'ShelfCore',
                '-emit-module', '-emit-module-path', str(temp / 'ShelfCore.swiftmodule'),
                '-c', *map(str, definitions), '-output-file-map', str(mapping)],
                capture_output=True, text=True, timeout=90)
            self.assertEqual(build.returncode, 0, build.stdout + build.stderr)
            extracted = temp / 'LensActions.swift'
            extracted.write_text(generated)
            executable = temp / 'lens-projection'
            result = subprocess.run([swiftc, *flags, '-parse-as-library', '-I', str(temp),
                str(ROOT / policy.FACT), str(extracted),
                str(ROOT / 'validation/v24-4/LensSelectionReference.swift'),
                str(ROOT / 'validation/v24-4/LensRouteDependencies.swift'),
                str(ROOT / 'validation/v24-4/LensProjectionHarness.swift'),
                *map(str, objects), '-o', str(executable)], capture_output=True, text=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            run = subprocess.run([str(executable)], capture_output=True, text=True, timeout=20)
            print(run.stdout, end='')
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertIn('Lens projection/navigation checks', run.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)
