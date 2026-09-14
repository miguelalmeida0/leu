"""A complete, non-overlapping native test inventory shared by execution and verification."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
APPLE_MARKER = '=== Leu Apple PDF integration and viewport geometry tests ==='
RELEASE_MARKER = '=== Leu Release regression (54) ==='
V24_MARKER = '=== Leu remaining V24 features (50 / 51 / 52 / 53 / 55 / 56) ==='
STUDY_MARKER = '=== Leu Study regression (36 / 39 / 40 / 48 / 49) ==='
REMAINING_MARKER = '=== Leu remaining UI regression (complete inventory, no repeats) ==='


def expected_tests(folder: Path) -> set[tuple[str, str]]:
    expected = set()
    for source in sorted(folder.glob('*.swift')):
        text = source.read_text()
        classes = re.findall(r'\b(?:final\s+)?class\s+(\w+)\s*:\s*\w+', text)
        methods = re.findall(r'\bfunc\s+(test\w+)\s*\(', text)
        if not methods:
            continue
        if len(classes) != 1 or len(methods) != len(set(methods)):
            raise ValueError('Ambiguous test inventory: ' + str(source))
        for method in methods:
            key = (classes[0], method)
            if key in expected:
                raise ValueError('Duplicate native test: ' + '/'.join(key))
            expected.add(key)
    return expected


def native_batches(root: Path = ROOT):
    apple = expected_tests(root / 'ShelfTests')
    ui = expected_tests(root / 'ShelfUITests')
    lock = json.loads((root / 'validation/v24-5/baseline-test-inventory.json').read_text())
    for name, actual in [('apple', apple), ('ui', ui)]:
        baseline = {tuple(item) for item in lock[name]}
        missing = baseline - actual
        if missing:
            raise ValueError('Baseline tests were removed: ' + ', '.join('/'.join(x) for x in sorted(missing)))
    release = {('ShelfWorldClassUITests', 'test54IrritatedCheckInOffersOptionalRelease')}
    v24 = {('ShelfWorldClassUITests', name) for name in [
        'test50SemanticQuestionUsesFourLevelCertainty',
        'test51UnderstandingLensUsesVerifiedSourceFacts',
        'test52V24PrivacyAndNeuralVoiceControlsAreExposed',
        'test53ActiveStudyContextSurvivesInterruption']}
    v24 |= {('ShelfEmotionalFlowUITests', name) for name in [
        'test55DrawingCannotHideReleaseOrExitControls',
        'test56DrainedCanFinishWithoutLosingCompletedHistory']}
    study = {('ShelfLearningOSUITests', name) for name in [
        'test36LearningTimelineAndConnectionsOpen',
        'test39LearningObjectSurvivesRelaunch', 'test40LearningStateIsARealRecallEntryPoint']}
    study |= {('ShelfStudyInteractionUITests', name) for name in [
        'test48ProgressReopensAfterScrollingAndBothTabsWork',
        'test49StudySecondaryButtonsOpenRealDestinationsAndCollapse']}
    required = release | v24 | study
    if not required <= ui:
        raise ValueError('Required acceptance tests are missing: ' + repr(required - ui))
    remaining = ui - required
    batches = [(APPLE_MARKER, 'ShelfTests', apple), (RELEASE_MARKER, 'ShelfUITests', release),
               (V24_MARKER, 'ShelfUITests', v24), (STUDY_MARKER, 'ShelfUITests', study),
               (REMAINING_MARKER, 'ShelfUITests', remaining)]
    scheduled = [test for _, target, tests in batches if target == 'ShelfUITests' for test in tests]
    if len(scheduled) != len(set(scheduled)) or set(scheduled) != ui:
        raise ValueError('UI batches must cover every test exactly once.')
    return batches
