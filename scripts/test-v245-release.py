#!/usr/bin/env python3
"""Actual portable Release-state tests, source mutations, and all-suite orchestration tests."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


policy = load('release_policy', 'check-v245-release.py')
coverage = load('qa_coverage', 'verify-qa-results.py')
runner = load('qa_runner', 'run-qa-suites.py')
from qa_inventory import native_batches, RELEASE_MARKER, REMAINING_MARKER


class ReleasePolicyTests(unittest.TestCase):
    def mutate(self, path, old, new):
        text = (ROOT / path).read_text()
        self.assertIn(old, text)
        self.assertTrue(policy.violations({path: text.replace(old, new)}))

    def testCurrentSource(self):
        self.assertEqual(policy.violations(), [])

    def testInlineCanvasRegressionRejected(self):
        self.mutate(policy.SUMMARY, 'private var summaryContent: some View {',
                    'private var summaryContent: some View { ReleaseSurface()')

    def testNonexclusiveReleaseRejected(self):
        self.mutate(policy.SUMMARY, 'if model.releasePresented {', 'if true {')

    def testOverlayCannotReplaceReservedControlSpace(self):
        self.mutate(policy.RELEASE, '.safeAreaInset(edge: .bottom, spacing: 0) { controls }', '.overlay { controls }')

    def testTinyTargetsRejected(self):
        self.mutate(policy.RELEASE, 'minHeight: 44', 'minHeight: 20')

    def testGestureCannotWrapActions(self):
        self.mutate(policy.RELEASE, 'private var controls: some View {',
                    'private var controls: some View { Canvas')

    def testNativeButtonsCannotBeReplaced(self):
        self.mutate(policy.RELEASE, '.buttonStyle(.plain)', '.buttonStyle(.plain).accessibilityElement(children: .ignore)')

    def testNoSwallowedExitSave(self):
        self.mutate(policy.SUMMARY, 'guard model.studySaveError == nil else { return }', '// swallowed error')

    def testBoundedDrawingRequired(self):
        self.mutate(policy.STATE, 'maximumPoints = 2_048', 'maximumPoints = Int.max')

    def testFullViewportAssertionCannotBeRelaxed(self):
        self.mutate(policy.HELPER, 'self.studyViewport(probe).contains(button.frame)', 'true')

    def testPinnedControlsCannotDependOnScrollRetry(self):
        self.mutate(policy.HELPER, 'app.buttons[identifier].tap()', 'dragStudyViewport(.zero, upward: true)')

    def testRealPortableReleaseState(self):
        with tempfile.TemporaryDirectory() as temp:
            binary = Path(temp) / 'release-tests'
            result = subprocess.run(['swiftc', '-swift-version', '5', '-strict-concurrency=complete',
                                     '-warnings-as-errors', str(ROOT / policy.STATE),
                                     str(ROOT / 'validation/v24-5/ReleaseStateHarness.swift'), '-o', str(binary)],
                                    capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run([str(binary)], capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('PASS: 27 Release state/recorded-geometry checks', result.stdout)
            print(result.stdout)


class CompleteInventoryTests(unittest.TestCase):
    def outcomes(self, tests, replacement=None):
        return '\n'.join(f"Test Case '-[ShelfUITests.{s} {m}]' {(replacement or {}).get((s,m), 'passed')} (1.0 seconds)."
                         for s, m in sorted(tests))

    def fullLog(self):
        return '\n'.join(marker + '\n' + self.outcomes(tests) + '\n** TEST SUCCEEDED **'
                         for marker, _, tests in native_batches()) + '\n'

    def testEveryOldAndNewTestRunsExactlyOnce(self):
        batches = native_batches()
        tests = [test for _, target, group in batches if target == 'ShelfUITests' for test in group]
        self.assertEqual(len(tests), 59)
        self.assertEqual(len(set(tests)), 59)
        self.assertEqual(len(batches[0][2]), 26)  # Exact inventory: original 20 plus six V25 checks.
        self.assertEqual(len(batches[-1][2]), 47)

    def testGreenFullCoverage(self):
        self.assertEqual(coverage.verify_all(self.fullLog()), [])

    def testMissingBatchRejected(self):
        self.assertTrue(coverage.verify_all(self.fullLog().split(REMAINING_MARKER)[0]))

    def testDuplicateSuccessfulExecutionRejected(self):
        marker, _, tests = native_batches()[1]
        log = marker + '\n' + self.outcomes(tests) + '\n' + self.outcomes(tests) + '\n** TEST SUCCEEDED **'
        self.assertTrue(coverage.verify(log, tests, marker))

    def testFailureAndRetryCannotBecomeGreen(self):
        marker, _, tests = native_batches()[1]
        log = marker + '\n' + self.outcomes(tests, {next(iter(tests)): 'failed'}) + '\n' + self.outcomes(tests) + '\n** TEST SUCCEEDED **'
        self.assertTrue(coverage.verify(log, tests, marker))

    def testSkippedTestRejected(self):
        self.assertTrue(coverage.verify_all(self.fullLog().replace("' passed", "' skipped", 1)))

    def testTestInWrongBatchRejected(self):
        marker, _, tests = native_batches()[1]
        other = {('Suite', 'testNotInThisBatch')}
        self.assertTrue(coverage.verify(marker + '\n' + self.outcomes(tests | other) + '\n** TEST SUCCEEDED **', tests, marker))

    def testRemovingBaselineTestRejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name in ['ShelfTests', 'ShelfUITests', 'validation/v24-5']:
                shutil.copytree(ROOT / name, root / name)
            p = root / 'ShelfUITests/ShelfUITests.swift'
            p.write_text(p.read_text().replace('func test00AccessibilityContract(', 'func removedAccessibilityContract('))
            with self.assertRaisesRegex(ValueError, 'Baseline tests were removed'):
                native_batches(root)

    def execute(self, fail_core=False, fail_release=False):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name in ['ShelfTests', 'ShelfUITests', 'validation/v24-5']:
                shutil.copytree(ROOT / name, root / name)
            scripts = root / 'scripts'; scripts.mkdir()
            (scripts / 'test-core.sh').write_text('#!/bin/bash\nexit ' + ('1' if fail_core else '0') + '\n')
            (scripts / 'test-ios.sh').write_text('''#!/bin/bash
printf '%s\\n' "$*" >> calls.txt
if [[ "$*" == *test54IrritatedCheckInOffersOptionalRelease* ]]; then exit ''' + ('65' if fail_release else '0') + '''; fi
exit 0
''')
            for p in scripts.glob('*.sh'): p.chmod(0o755)
            with contextlib.redirect_stdout(io.StringIO()) as output:
                code = runner.run(root, root / 'run')
            calls = (root / 'calls.txt').read_text().splitlines()
            records = json.loads((root / 'run/suite-results.json').read_text())
            return code, calls, records, output.getvalue()

    def testUIFailureDoesNotHideOtherTests(self):
        code, calls, records, text = self.execute(fail_release=True)
        self.assertEqual(code, 65)
        self.assertEqual(len(calls), 5)
        self.assertEqual(len(records), 6)
        self.assertEqual(sum('test54Irritated' in line for line in calls), 1)
        self.assertIn(REMAINING_MARKER, text)
        self.assertEqual(records[-1]['exitCode'], 0)

    def testCoreFailureDoesNotHideNativeResults(self):
        code, calls, records, _ = self.execute(fail_core=True, fail_release=True)
        self.assertEqual(code, 1)
        self.assertEqual(len(calls), 5)
        self.assertEqual(records[2]['exitCode'], 65)

    def testGenuinelyGreenOrchestrationReturnsZero(self):
        code, calls, records, _ = self.execute()
        self.assertEqual(code, 0)
        self.assertEqual(len(records), 6)
        self.assertEqual(sum(len(line.split('-only-testing:'))-1 for line in calls), 85)


if __name__ == '__main__':
    unittest.main(verbosity=2)
