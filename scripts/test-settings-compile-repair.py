#!/usr/bin/env python3
"""Regression fixtures for the V24 Settings overload and complete-log clipboard summary."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from swiftui_section_contract import violations

ROOT = Path(__file__).resolve().parents[1]


class SectionContractTests(unittest.TestCase):
    def testRejectsTitleAndFooterShorthand(self):
        self.assertEqual(violations('Section("Voice") { Text("Engine") } footer: { Text("Offline") }'), [1])

    def testAcceptsExplicitHeaderAndFooter(self):
        self.assertEqual(violations('Section { Text("Engine") } header: { Text("Voice") } footer: { Text("Offline") }'), [])

    def testAcceptsTitleOnlySection(self):
        self.assertEqual(violations('Section("Voice") { Text("Engine") }'), [])

    def testAcceptsOlderLabeledInitializer(self):
        self.assertEqual(violations('Section(header: Text("Voice"), footer: Text("Offline")) { Text("Engine") }'), [])

    def testDoesNotConfuseSiblingSections(self):
        self.assertEqual(violations('Section("One") { Text("First") }\nSection { Text("Second") } footer: { Text("Footer") }'), [])

    def testHandlesNestedBodiesStringsAndComments(self):
        source = '''// Section("not real") {} footer: {}
Section("Voice") {
  if ready { Button("} footer: {") { run() } }
  Text(#"raw } /*"#)
  /* /* nested */ } */
} footer: { Text("Explanation") }
'''
        self.assertEqual(violations(source), [2])

    def testMasksMultilineStringsAndEscapedQuotes(self):
        source = 'Section("Voice") { Text("""\n}\n""")\nText("say \\\"hi\\\"") } footer: { Text("After") }'
        self.assertEqual(violations(source), [1])

    def testRejectsVariableTitleWithFooter(self):
        self.assertEqual(violations('Section(title) { Text("Voice") } footer: { Text("After") }'), [1])

    def testCurrentSettingsAndOriginalMutation(self):
        source = (ROOT / 'Shelf/Features/Settings/SettingsScreen.swift').read_text()
        self.assertEqual(violations(source), [])
        # Reintroduce precisely the two-line constructor mistake, not a fake token.
        mutation = source.replace('Section {\n                    LabeledContent("Reading voice"',
                                  'Section("Voice") {\n                    LabeledContent("Reading voice"')
        mutation = mutation.replace('} header: {\n                    Text("Voice")\n                } footer: {', '} footer: {')
        self.assertNotEqual(mutation, source)
        self.assertEqual(len(violations(mutation)), 1)


class CompilerSummaryTests(unittest.TestCase):
    def summarize(self, contents: str) -> str:
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'qa.log'
            log.write_text(contents)
            result = subprocess.run([sys.executable, str(ROOT / 'scripts/summarize-qa.py'), str(log)],
                                    text=True, capture_output=True, check=True)
            return result.stdout

    def testEarlyErrorAndSourceContextSurviveLongBuildTail(self):
        error = '/project/SettingsScreen.swift:90:17: error: no matching initializer'
        log = ('=== Leu native compile gate ===\n' + error + '\n'
               'Section("Voice") {\n    ^\n'
               '/sdk/Section.swift:1: note: candidate requires empty footer\n' +
               '\n'.join(f'SwiftCompile ordinary-file-{i}.swift' for i in range(1500)) +
               '\n** BUILD FAILED **\nThe following build commands failed:\n'
               'SwiftCompile normal arm64 SettingsScreen.swift\n')
        summary = self.summarize(log)
        self.assertIn(error, summary)
        self.assertIn('Section("Voice")', summary)
        self.assertIn('candidate requires empty footer', summary)
        self.assertIn('SwiftCompile normal arm64 SettingsScreen.swift', summary)
        self.assertIn('** BUILD FAILED **', summary)
        self.assertLess(len(summary.splitlines()), 25)

    def testAnsiDiagnosticsRetained(self):
        summary = self.summarize('\x1b[31mfile.swift:5: error: actual error\x1b[0m\n** BUILD FAILED **\n')
        self.assertIn('error: actual error', summary)
        self.assertNotIn('\x1b', summary)

    def testMissingDiagnosticIsExplicit(self):
        summary = self.summarize('SwiftCompile SettingsScreen.swift\n** BUILD FAILED **\n')
        self.assertIn('without a captured compiler error diagnostic', summary)

    def testMultipleDiagnosticsRemain(self):
        summary = self.summarize('one.swift:1: error: one\n' + 'ordinary\n' * 400 +
                                 'two.swift:1: error: two\n** BUILD FAILED **\n')
        self.assertIn('error: one', summary)
        self.assertIn('error: two', summary)

    def testSuccessDoesNotClaimMissingError(self):
        summary = self.summarize('=== Leu native compile gate ===\n** BUILD SUCCEEDED **\n')
        self.assertNotIn('FAIL:', summary)


if __name__ == '__main__':
    unittest.main(verbosity=2)
