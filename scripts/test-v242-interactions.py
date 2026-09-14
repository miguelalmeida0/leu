#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('policy',ROOT/'scripts/check-v242-interactions.py')
policy=importlib.util.module_from_spec(spec);spec.loader.exec_module(policy)

class PolicyTests(unittest.TestCase):
    def mutate(self,path,old,new):
        text=(ROOT/path).read_text();self.assertIn(old,text)
        self.assertTrue(policy.violations(overrides={path:text.replace(old,new)}))
    def testCurrentSource(self): self.assertEqual(policy.violations(),[])
    def testReaderContainerRegression(self):
        self.mutate('Shelf/Features/Reader/ReaderScreen.swift','UITestFrameProbe(identifier: "reader-screen")','Color.clear.accessibilityIdentifier("reader-screen")')
    def testQuestionContainerRegression(self):
        self.mutate('Shelf/Learning/QuestionCardView.swift','UITestFrameProbe(identifier: "question-card")','Color.clear.accessibilityIdentifier("question-card")')
    def testFeelingContainerRegression(self):
        self.mutate('Shelf/Learning/SessionCompleteView.swift','UITestFrameProbe(identifier: "emotional-check-in")','Color.clear.accessibilityIdentifier("emotional-check-in")')
    def testReturnMustStayAButton(self):
        self.mutate('Shelf/Features/Reader/Components/ReaderTopBar.swift','.accessibilityIdentifier("reader-context-return")','.accessibilityElement(children: .ignore).accessibilityIdentifier("reader-context-return")')
    def testLensCannotMasqueradeAsQuestion(self):
        self.mutate('Shelf/Learning/UnderstandingLensSheet.swift','queueLensNavigation','openSource')
    def testMissingLaunchHandoff(self):
        self.mutate('Shelf/App/RootView.swift','primaryArea = .learn','primaryArea = .shelf')
    def testMissingReturnContext(self):
        self.mutate('Shelf/App/RootView.swift','restoreLens: destination.restoreLens','restoreLens: nil')
    def testUnorderedWrites(self):
        self.mutate('Shelf/Learning/LearningModel+Recovery.swift','await previous?.value','await Task.yield()')
    def testSwallowedErrors(self):
        self.mutate('Shelf/Learning/LearningModel+Recovery.swift','studySaveError = error.localizedDescription','studySaveError = nil')
    def testStaleQuestionContext(self):
        self.mutate('Shelf/Learning/LearningModel+Recovery.swift','context.questionID == question.id','true')
    def testSettingsMustAccountForRecycledRows(self):
        self.mutate('ShelfUITests/V24InteractionSupport.swift','upward: false','upward: true')
    def testEmotionMustUseRealOption(self):
        self.mutate('ShelfUITests/V24InteractionSupport.swift','tapStudyButton("question-option-0"','identifiedControl("question-option-0"')
    def testWaitsForTransitions(self):
        self.mutate('ShelfUITests/V24InteractionSupport.swift','XCTNSPredicateExpectation(predicate: advanced','XCTNSPredicateExpectation(predicate: NSPredicate(value: true)')

class SummaryTests(unittest.TestCase):
    def summary(self,text):
        with tempfile.NamedTemporaryFile(mode='w',suffix='.log') as f:
            f.write(text);f.flush()
            return subprocess.check_output([sys.executable,str(ROOT/'scripts/summarize-qa.py'),f.name],text=True)
    def testRoutineBuildNotesDoNotFloodClipboard(self):
        text='\n'.join('note: ordinary build dependency '+str(i) for i in range(1500))+'\n** BUILD SUCCEEDED **\n'
        output=self.summary(text);self.assertLess(len(output.splitlines()),10);self.assertIn('BUILD SUCCEEDED',output)
    def testWarningsRemainVisibleOnce(self):
        text=('file.swift:1: warning: concurrency warning\nnote: Swift 6 explanation\n'*300)+'** BUILD SUCCEEDED **\n'
        output=self.summary(text);self.assertIn('300 occurrence(s)',output);self.assertEqual(output.count('concurrency warning'),1)
    def testRealErrorSurvivesNotesAndWarnings(self):
        text='file.swift:1: error: broken type\nlet result = broken\n^\nnote: use the correct type\n'+('note: ordinary build\n'*1500)+'** BUILD FAILED **\n'
        output=self.summary(text);self.assertIn('error: broken type',output);self.assertIn('let result = broken',output);self.assertIn('use the correct type',output)

if __name__=='__main__': unittest.main(verbosity=2)
