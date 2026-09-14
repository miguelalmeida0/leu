#!/usr/bin/env python3
"""Portable regression tests for the repair's source policies, coverage parser and QA wrapper."""
from __future__ import annotations
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def load(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


coverage = load('qa_coverage', 'verify-qa-results.py')
policy = load('study_policy', 'check-study-interactions.py')
collector = load('qa_collector', 'collect-qa-diagnostics.py')


class CoverageTests(unittest.TestCase):
    expected = {('Suite', 'testOne'), ('Suite', 'testTwo')}
    marker = '=== Native stage ==='

    def log(self, outcomes: list[tuple[str, str]]) -> str:
        return self.marker + '\n' + '\n'.join(
            f"Test Case '-[App.Suite {method}]' {status} (1.0 seconds)." for method, status in outcomes
        ) + '\n** TEST SUCCEEDED **\n'

    def testCompleteRun(self):
        self.assertEqual(coverage.verify(self.log([('testOne', 'passed'), ('testTwo', 'passed')]), self.expected, self.marker), [])

    def testMissingTestRejected(self):
        self.assertTrue(coverage.verify(self.log([('testOne', 'passed')]), self.expected, self.marker))

    def testSkipRejected(self):
        self.assertTrue(coverage.verify(self.log([('testOne', 'passed'), ('testTwo', 'skipped')]), self.expected, self.marker))

    def testFailureThenRetryPassRejected(self):
        log = self.log([('testOne', 'failed'), ('testOne', 'passed'), ('testTwo', 'passed')])
        self.assertTrue(coverage.verify(log, self.expected, self.marker))

    def testDuplicatePassNotExtraCoverage(self):
        self.assertTrue(coverage.verify(self.log([('testOne', 'passed'), ('testOne', 'passed')]), self.expected, self.marker))

    def testPriorStageCannotSatisfyMissingCurrentStage(self):
        self.assertTrue(coverage.verify(self.log([('testOne', 'passed'), ('testTwo', 'passed')]), self.expected, '=== Missing stage ==='))

    def testMissingNativeSuccessRejected(self):
        log = self.log([('testOne', 'passed'), ('testTwo', 'passed')]).replace('** TEST SUCCEEDED **', '')
        self.assertTrue(coverage.verify(log, self.expected, self.marker))

    def testSourceInventory(self):
        self.assertEqual(len(coverage.expected_tests(ROOT / 'ShelfTests')), 26)  # 20 preserved + 6 V25 PDF checks
        self.assertEqual(len(coverage.expected_tests(ROOT / 'ShelfUITests')), 59)  # 57 preserved + 2 V25 journeys


class PolicyTests(unittest.TestCase):
    def testCurrentTree(self):
        self.assertEqual(policy.check(ROOT), [])

    def testRejectsButtonSemanticsRegression(self):
        with tempfile.TemporaryDirectory() as temp:
            destination = Path(temp)
            path = destination / 'Shelf/Learning/Components/LearnSecondaryModes.swift'
            path.parent.mkdir(parents=True)
            path.write_text((ROOT / path.relative_to(destination)).read_text() + '\n.accessibilityElement(children: .ignore)\n')
            self.assertTrue(any('retain native accessibility' in e for e in policy.check(destination)))

    def testRejectsGenericNodeTargeting(self):
        with tempfile.TemporaryDirectory() as temp:
            destination = Path(temp)
            path = destination / 'ShelfUITests/StudyInteractionSupport.swift'
            path.parent.mkdir(parents=True)
            path.write_text('identifiedControl(identifier)')
            self.assertTrue(any('generic accessibility node' in e for e in policy.check(destination)))

    def testRejectsMissingViewportContainment(self):
        with tempfile.TemporaryDirectory() as temp:
            destination = Path(temp)
            path = destination / 'ShelfUITests/StudyInteractionSupport.swift'
            path.parent.mkdir(parents=True)
            path.write_text((ROOT / path.relative_to(destination)).read_text().replace('viewport.contains(frame)', 'true'))
            self.assertTrue(any('viewport.contains(frame)' in e for e in policy.check(destination)))


class DisclosurePolicyTests(unittest.TestCase):
    def source(self) -> str:
        return (ROOT / 'Shelf/Learning/Components/LearnSecondaryModes.swift').read_text()

    def testRealConditionalDisclosureAccepted(self):
        self.assertEqual(policy.disclosure_errors(self.source()), [])

    def testMissingConditionalRejected(self):
        text = self.source().replace('if model.moreLearningExpanded {', 'if true {')
        self.assertTrue(any('structurally removed' in e for e in policy.disclosure_errors(text)))

    def testEmptyConditionalBeforePersistentRowsRejected(self):
        text = self.source().replace('if model.moreLearningExpanded {', 'if model.moreLearningExpanded {}\nif true {')
        self.assertTrue(any('structurally removed' in e for e in policy.disclosure_errors(text)))

    def testEverySecondaryRowMustBeConditional(self):
        for title in ['Connections', 'Document topics', 'Search ideas']:
            with self.subTest(title=title):
                text = self.source() + f'\ndetailRow("{title}", detail: "outside branch") {{}}'
                self.assertTrue(any('structurally removed' in e for e in policy.disclosure_errors(text)))

    def testZeroHeightHideRegressionRejected(self):
        text = self.source() + '\n.frame(maxHeight: model.moreLearningExpanded ? 190 : 0)'
        self.assertTrue(any('preserve hidden controls' in e for e in policy.disclosure_errors(text)))

    def testNoStaleActivationGuardRejected(self):
        text = self.source().replace('guard model.moreLearningExpanded else { return }', '')
        self.assertTrue(any('stale collapsed activation' in e for e in policy.disclosure_errors(text)))

    def testAnimatedOutgoingControlsRejected(self):
        text = self.source().replace('.transition(.identity)', '.transition(.opacity)')
        self.assertTrue(any('outgoing animation' in e for e in policy.disclosure_errors(text)))

    def testCommentsCannotSatisfyStructuralPolicy(self):
        text = self.source().replace('if model.moreLearningExpanded {', 'if true {')
        text += '\n// if model.moreLearningExpanded {'
        self.assertTrue(any('structurally removed' in e for e in policy.disclosure_errors(text)))


class SummaryTests(unittest.TestCase):
    def testOnlyFailingJourneyTreeReachesClipboard(self):
        with tempfile.TemporaryDirectory() as temp:
            log = Path(temp) / 'qa.log'
            log.write_text("""LEU_UI_TREE_BEGIN: failed-journey
old mislabeled tree of a passing test
LEU_UI_TREE_END: failed-journey
Test Case '-[ShelfUITests.ShelfLearningOSUITests test36]' passed (2.0 seconds).
LEU_UI_TREE_BEGIN: collapsed-study-tools-remain
actual failed disclosure tree
LEU_UI_TREE_END: collapsed-study-tools-remain
Test Case '-[ShelfUITests.ShelfStudyInteractionUITests test49]' failed (3.0 seconds).
** TEST FAILED **
""")
            process = subprocess.run([sys.executable, str(ROOT / 'scripts/summarize-qa.py'), str(log)],
                                     capture_output=True, text=True)
            self.assertEqual(process.returncode, 0)
            self.assertNotIn('old mislabeled tree', process.stdout)
            self.assertIn('actual failed disclosure tree', process.stdout)
            self.assertIn("test36]' passed", process.stdout)
            self.assertIn("test49]' failed", process.stdout)
            self.assertIn('** TEST FAILED **', process.stdout)

    def testUnfinishedTestTreeIsNotDiscarded(self):
        with tempfile.TemporaryDirectory() as temp:
            log = Path(temp) / 'qa.log'
            log.write_text('LEU_UI_TREE_BEGIN: interrupted\nuseful pending tree\nLEU_UI_TREE_END: interrupted\nxcodebuild: error: lost runner\n')
            process = subprocess.run([sys.executable, str(ROOT / 'scripts/summarize-qa.py'), str(log)],
                                     capture_output=True, text=True)
            self.assertIn('useful pending tree', process.stdout)
            self.assertIn('lost runner', process.stdout)


class WrapperTests(unittest.TestCase):
    def execute_wrapper(self, qa_exit: int, export_exit: int, coverage_exit: int = 0):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); scripts = root / 'scripts'; scripts.mkdir()
            (root / 'bin').mkdir()
            shutil.copy2(ROOT / 'scripts/qa-and-copy.sh', scripts / 'qa-and-copy.sh')
            (scripts / 'qa-native.sh').write_text(f'#!/bin/bash\necho "=== fixture ==="\nexit {qa_exit}\n')
            (scripts / 'qa-native.sh').chmod(0o755)
            (scripts / 'summarize-qa.py').write_text('print("fixture summary")\n')
            (scripts / 'collect-qa-diagnostics.py').write_text(f'print("fixture diagnostics"); raise SystemExit({export_exit})\n')
            (scripts / 'verify-qa-results.py').write_text(f'print("fixture coverage"); raise SystemExit({coverage_exit})\n')
            copy = root / 'bin/pbcopy'; copy.write_text('#!/bin/bash\ncat > "$COPY_TARGET"\n'); copy.chmod(0o755)
            env = {**os.environ, 'PATH': str(root / 'bin') + ':' + os.environ['PATH'], 'COPY_TARGET': str(root / 'clipboard.txt')}
            process = subprocess.run(['bash', str(scripts / 'qa-and-copy.sh')], env=env, capture_output=True, text=True)
            return process.returncode, (root / 'clipboard.txt').read_text()

    def testFailingQAStillCopiesAndExports(self):
        code, copied = self.execute_wrapper(65, 0)
        self.assertEqual(code, 65); self.assertIn('fixture diagnostics', copied); self.assertIn('exit code: 65', copied)

    def testExporterCannotMaskTestFailure(self):
        code, copied = self.execute_wrapper(65, 7)
        self.assertEqual(code, 65); self.assertIn('Diagnostics export failed', copied)

    def testSuccessfulQAIsPreserved(self):
        code, copied = self.execute_wrapper(0, 0)
        self.assertEqual(code, 0); self.assertIn('exit code: 0', copied)

    def testMissingCoveragePreventsGreen(self):
        code, copied = self.execute_wrapper(0, 0, 1)
        self.assertEqual(code, 1); self.assertIn('exit code: 1', copied)


class DiagnosticsTests(unittest.TestCase):
    def testPortableExportKeepsOriginalFailureAndFullLog(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); run = root / 'run'; run.mkdir()
            log = root / 'qa.log'; log.write_text('original failure\n')
            with contextlib.redirect_stdout(io.StringIO()):
                archive = collector.collect(root, run, log, 65)
            with zipfile.ZipFile(archive) as bundle:
                self.assertEqual(bundle.read('qa-full.log'), b'original failure\n')
                self.assertEqual(json.loads(bundle.read('manifest.json'))['qaExitCode'], 65)


if __name__ == '__main__':
    unittest.main(verbosity=2)
