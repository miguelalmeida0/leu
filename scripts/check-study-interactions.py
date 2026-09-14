#!/usr/bin/env python3
"""Source-policy checks for the repaired input boundary; not native behavioral certification."""
from pathlib import Path
import sys
import re


def disclosure_errors(text: str) -> list[str]:
    """A narrow source policy, not a Swift parser or a substitute for XCUITest."""
    errors: list[str] = []
    # Ignore comments so a comment cannot accidentally satisfy the structural contract.
    code = re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S)
    marker = "if model.moreLearningExpanded {"
    start = code.find(marker)
    body = ""
    if start >= 0:
        opening = start + len(marker) - 1
        depth = 1
        closing = opening + 1
        while closing < len(code) and depth:
            depth += (code[closing] == "{") - (code[closing] == "}")
            closing += 1
        body = code[opening + 1:closing - 1] if depth == 0 else ""
    for title in ["Connections", "Document topics", "Search ideas"]:
        call = f'detailRow("{title}"'
        if body.count(call) != 1 or code.count(call) != 1:
            errors.append(f"Collapsed Study tools must be structurally removed: {title} must exist only inside the expanded branch.")
    # These were the V23.10 collapse mechanism: children survived with full hit frames.
    for token in [".frame(maxHeight:", ".opacity(model.moreLearningExpanded", ".accessibilityElement(children: .contain)"]:
        if token in code:
            errors.append(f"Study disclosure must not preserve hidden controls using {token}")
    if "guard model.moreLearningExpanded else { return }" not in code:
        errors.append("Secondary Study actions must reject stale collapsed activation.")
    if ".transition(.identity)" not in body:
        errors.append("Study tools must not remain alive in an outgoing animation.")
    return errors


def check(root: Path) -> list[str]:
    errors: list[str] = []
    required = {
        'Shelf/Learning/Components/LearnSecondaryModes.swift': [
            'Button {', 'action()', 'identifier: "learning-progress", action: onProgress',
            '.frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)'],
        'ShelfUITests/StudyInteractionSupport.swift': [
            'app.buttons.matching(identifier: identifier)', 'viewport.contains(frame)',
            'navigation.frame.minY', 'query.count == 1', 'button.tap()', 'studyCheckpoint("before-',
            'studyCheckpoint("after-'],
        'Shelf/App/RootView.swift': ['.onChange(of: container.learning.activeSession?.id)',
                                   'StudyInteractionTrace.record("route.session.requested")'],
        'ShelfUITests/ShelfLearningOSUITests.swift': ['let savedEventID = savedEvent.identifier',
            'app.buttons[savedEventID]', 'tapStudyButton(react.identifier, scrollID: "progress-now-scroll")'],
        'ShelfUITests/ShelfUITestCase.swift': ['LEU_UI_TREE_BEGIN:', 'LEU_UI_DIAGNOSTICS', 'testRun?.totalFailureCount'],
        'ShelfUITests/ShelfStudyInteractionUITests.swift': ['expectStudyToolsRemoved()',
            'matching(identifier: $0).count == 0', 'XCTAssertFalse(app.buttons[identifier].exists',
            'XCTAssertFalse(app.buttons[identifier].isHittable'],
        'scripts/test-ios.sh': ['STATUS=$?', 'exit "$STATUS"', 'native-results.txt'],
        'scripts/qa-and-copy.sh': ['collect-qa-diagnostics.py', 'verify-qa-results.py', 'pbcopy < "$SUMMARY"'],
    }
    for name, tokens in required.items():
        path = root / name
        if not path.is_file():
            errors.append(f'Missing {name}')
            continue
        text = path.read_text()
        errors += [f'{name}: missing {token}' for token in tokens if token not in text]
    secondary = root / 'Shelf/Learning/Components/LearnSecondaryModes.swift'
    if secondary.is_file() and '.accessibilityElement(children: .ignore)' in secondary.read_text():
        errors.append('Study Buttons must retain native accessibility semantics; do not replace them with empty ignore elements.')
    if secondary.is_file():
        errors += disclosure_errors(secondary.read_text())
    helper = root / 'ShelfUITests/StudyInteractionSupport.swift'
    if helper.is_file() and 'identifiedControl(' in helper.read_text():
        errors.append('Study action targeting must not fall back to a generic accessibility node.')
    for path in (root / 'ShelfUITests').glob('*.swift'):
        if 'XCTSkip(' in path.read_text():
            errors.append(f'{path.name}: release UI journeys must not silently skip.')
    return errors


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    errors = check(root)
    if errors:
        print('FAIL: Study input contract')
        print('\n'.join(' - ' + error for error in errors))
        return 1
    print('PASS: Study native-button, visible-viewport, session handoff, collapsed-subtree and diagnostic source contracts (runtime still requires Xcode).')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
