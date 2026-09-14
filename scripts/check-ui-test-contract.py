#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
ui = root / "ShelfUITests"
violations = []
for path in ui.glob("*.swift"):
    text = path.read_text()
    forbidden = {
        'readerTool(identifier: "reader-tool-study"': "legacy Study tool no longer exists; open Study marks from reader-tool-mark",
        'app.buttons["Text"].tap()': "visual Text label differs from accessibility label; use readerTextControl()",
        'app.buttons["Zoom"].tap()': "visual Zoom label differs from accessibility label; use readerTextControl()",
        'element("readable-surface").swipe': "gesture QA must drive the hit-tested reader viewport by coordinate",
        'element("pdf-surface").swipe': "gesture QA must drive the hit-tested reader viewport by coordinate",
        'app.buttons["tab-favorites"]': "V23 uses Library filters, not a second navigation tier",
        'app.buttons["tab-recents"]': "V23 uses Library filters, not a second navigation tier",
        'app.buttons["tab-settings"]': "Settings lives in Library options, not a second navigation tier",
        'chooseFlow("Vertical scroll")': "V23 Reading Settings labels this segmented option Vertical",
        'chooseFlow("Horizontal pages")': "V23 Reading Settings labels this segmented option Horizontal",
        'app.buttons["Active Recall"].tap()': "redesigned compound rows must use their stable accessibility identifier",
        'app.buttons["Interview Mode"].tap()': "redesigned compound rows must use their stable accessibility identifier",
        'app.buttons["Progress history"].tap()': "learning menu items must use stable semantic lookup",
        'app.buttons["Progress now"].tap()': "learning menu items must use stable semantic lookup",
        'app.buttons["Library"].tap()': "Library is intentionally visible in multiple scopes; use the unique semantic action",
    }
    for needle, reason in forbidden.items():
        if needle in text:
            violations.append(f"{path.relative_to(root)}: {reason}")

required = {
    ui / "ShelfUITestCase.swift": ["swipeReaderContentLeft", "swipeReaderContentRight", "scrubberControl", "readerTextControl", "identifiedControl"],
    ui / "ShelfLearningOSUITests.swift": [
        'identifiedControl("commit-answer", label: "Commit answer")',
        'identifiedControl("view-question-source", label: "View source")',
        'waitForEnabled(commit, timeout: 5)'
    ],
    root / "Shelf/Features/Reader/Components/ReaderTextSizeMenu.swift": ["reader-tool-text", "reader-tool-zoom"],
    root / "Shelf/Features/Reader/Components/ReaderBottomBar.swift": ["reader-tool-learn", "reader-tool-mark", "Your Marks", "reader-bottom-bar-frame", "reader-transport-row"],
    root / "Shelf/Features/Reader/Components/ReaderFocusBar.swift": ["reader-focus-chrome-frame"],
    root / "Shelf/Features/Reader/ReaderScreen.swift": ["original-viewport-frame"],
    root / "Shelf/Features/Reader/ReaderSettingsSheet.swift": ["settings-keep-awake", "ShelfSwitch(", "isOn: $preferences.keepAwake"],
    root / "Shelf/Learning/LearnTodayScreen.swift": ["learn-screen", "start-learning-session"],
    root / "Shelf/Learning/Components/LearnSecondaryModes.swift": [
        "learning-more", "learning-mode-active-recall", "learning-mode-interview",
        "learning-progress", "learning-connections"
    ],
    root / "Shelf/Learning/LearningStateSheet.swift": [
        "Your understanding", "progress-tab-now", "progress-tab-history",
        "progress-now-view", "progress-history-view"
    ],
    root / "Shelf/Learning/LearningObjectActionSheet.swift": [
        "learning-object-actions", "learning-action-remember", "learning-action-test",
        "learning-action-connect", "learning-action-mask", "learning-action-explain", "learning-action-understand", "reader.requestLens(source)"
    ],
    root / "Shelf/Learning/Components/PrimaryTabBar.swift": ['accessibilityIdentifier("primary-" + area.rawValue)'],
    root / "Shelf/Features/Library/Components/LibraryHeader.swift": ["library-filter-all", "library-filter-favorites", "library-filter-recents", "library-filter-tags"],
    root / "Shelf/Features/Reader/Components/ReaderTopBar.swift": ["reader-context-return", ".accessibilityLabel(model.returnLabel)"],
    root / "Shelf/Features/Collections/TagsScreen.swift": ["library-tags-back"],
    root / "Shelf/Features/Reader/Components/ReaderBottomBar.swift": ["reader-search-return"],
}

settings_path = root / "Shelf/Features/Reader/ReaderSettingsSheet.swift"
settings_text = settings_path.read_text()
controls_path = root / "Shelf/DesignSystem/ShelfControls.swift"
controls_text = controls_path.read_text()
if "struct ShelfSwitch: UIViewRepresentable" not in controls_text or "UISwitch" not in controls_text or ".valueChanged" not in controls_text:
    violations.append(f"{controls_path.relative_to(root)}: Keep Awake must use the UIKit-backed first-touch switch contract")
if 'Toggle("Keep screen awake"' in settings_text:
    violations.append(f"{settings_path.relative_to(root)}: reader Keep Awake must not regress to SwiftUI Toggle; use ShelfSwitch")
if '.accessibilityValue(preferences.keepAwake' in settings_text:
    violations.append(f"{settings_path.relative_to(root)}: do not override native Toggle accessibilityValue; XCUI/VoiceOver must receive the real switch state")

for path, needles in required.items():
    text = path.read_text()
    for needle in needles:
        if needle not in text:
            violations.append(f"{path.relative_to(root)}: missing required QA/accessibility contract token {needle}")

# V23 has one navigation tier. Library scopes are filters, never a second tab bar.
root_view = (root / "Shelf/App/RootView.swift").read_text() if (root / "Shelf/App/RootView.swift").exists() else ""
if "ShelfSectionSwitcher(" in root_view:
    violations.append("Shelf/App/RootView.swift: Gallery Minimalism IA must not reintroduce the legacy two-tier Shelf switcher")

# Study keeps Progress first-class and uses inline progressive disclosure only for advanced tools.
# Progress now/history are two views of one sheet, not sibling destinations.
secondary_modes = (root / "Shelf/Learning/Components/LearnSecondaryModes.swift").read_text()
progress_sheet = (root / "Shelf/Learning/LearningStateSheet.swift").read_text()
if "Menu {" in secondary_modes:
    violations.append("Shelf/Learning/Components/LearnSecondaryModes.swift: secondary Study actions must use inline progressive disclosure, not SwiftUI Menu")
for legacy in ['detailRow("Progress now"', 'detailRow("Progress history"', 'identifier: "learning-progress-now"', 'identifier: "learning-progress-history"']:
    if legacy in secondary_modes:
        violations.append(f"Shelf/Learning/Components/LearnSecondaryModes.swift: unified Progress must not regress to split destination {legacy}")
for token in ["moreLearningExpanded", 'row("Progress"', 'identifier: "learning-progress"', 'identifier: "learning-connections"']:
    if token not in secondary_modes:
        violations.append(f"Shelf/Learning/Components/LearnSecondaryModes.swift: missing unified Progress / disclosure contract token {token}")
for token in ["progress-tab-now", "progress-tab-history", "progress-now-view", "progress-history-view"]:
    if token not in progress_sheet:
        violations.append(f"Shelf/Learning/LearningStateSheet.swift: missing unified Progress view token {token}")


# Secondary Study destinations use one typed presenter. Progress is deliberately NOT a sheet:
# it is a first-class Study root state so its Now/History controls are always in the app hierarchy.
for legacy in [
    '.sheet(isPresented: $model.learningStatePresented)',
    '.sheet(isPresented: $model.connectionsOverviewPresented)',
    '.sheet(isPresented: $model.documentTopicsPresented)',
    '.sheet(isPresented: $model.interviewSetupPresented)',
    '.sheet(isPresented: $model.activeRecallSetupPresented)',
]:
    if legacy in secondary_modes:
        violations.append(f"Shelf/Learning/Components/LearnSecondaryModes.swift: secondary Study destinations must use one typed presenter, not {legacy}")
for token in ['@State private var presentedDestination: Destination?', '.sheet(item: $presentedDestination)', 'case connections, documentTopics, interview, activeRecall, searchIdeas']:
    if token not in secondary_modes:
        violations.append(f"Shelf/Learning/Components/LearnSecondaryModes.swift: missing deterministic typed sheet contract token {token}")


# Progress must bypass presentation APIs and domain-model presentation flags entirely.
# RootView owns the Study sub-route because it is the stable app root that owns primary IA.
learn_today = (root / "Shelf/Learning/LearnTodayScreen.swift").read_text()
learning_model = (root / "Shelf/Learning/LearningModel.swift").read_text()
for forbidden in [
    '@State private var progressPresented',
    'LearningStateSheet(model: model)',
    'progressPresented = true',
    'learningStatePresented',
]:
    if forbidden in learn_today or forbidden in learning_model:
        violations.append(f"Learning Progress routing must not depend on child/model presentation state: {forbidden}")
for token in ['let onOpenProgress: () -> Void', 'LearnSecondaryModes(model: model, knowledge: knowledge)', 'onOpenProgress()']:
    if token not in learn_today:
        violations.append(f"Shelf/Learning/LearnTodayScreen.swift: missing root-route Progress callback token {token}")
for token in ['@State private var studySurface: StudySurface = .landing', 'case .progress:', 'LearningStateSheet(model: container.learning)', 'studySurface = .progress', 'studySurface = .landing']:
    if token not in root_view:
        violations.append(f"Shelf/App/RootView.swift: missing stable root-owned Study route token {token}")
for token in ['let onProgress: () -> Void', 'identifier: "learning-progress", action: onProgress']:
    if token not in secondary_modes:
        violations.append(f"Shelf/Learning/Components/LearnSecondaryModes.swift: missing direct Progress callback token {token}")
if 'case progress' in secondary_modes or 'presentedDestination = .progress' in secondary_modes:
    violations.append("Shelf/Learning/Components/LearnSecondaryModes.swift: Progress must never regress to modal presentation")
for forbidden in ['NavigationStack {', r'@Environment(\.dismiss)', '.sheet(', '.fullScreenCover(', '.accessibilityIdentifier("learning-state-sheet")']:
    if forbidden in progress_sheet:
        violations.append(f"Shelf/Learning/LearningStateSheet.swift: Progress root must remain flat/non-modal and expose child semantics; found {forbidden}")
for token in ['let onDone: () -> Void', 'Button("Done", action: onDone)', 'Your understanding', 'progress-tab-now', 'progress-tab-history', 'progress-now-view', 'progress-history-view']:
    if token not in progress_sheet:
        violations.append(f"Shelf/Learning/LearningStateSheet.swift: missing deterministic Progress control token {token}")

# Learning actions are semantic controls, not test-visible text embedded in compound labels.
actions_text = (root / "Shelf/Learning/LearningObjectActionSheet.swift").read_text()
for action in ["Remember", "Test", "Connect", "Mask", "Explain"]:
    if f'.accessibilityLabel(title)' not in actions_text:
        violations.append("Shelf/Learning/LearningObjectActionSheet.swift: learning actions require explicit accessibility labels")
        break

worldclass_tests = (ui / "ShelfWorldClassUITests.swift").read_text()
if 'typeText("useEffect")' in worldclass_tests:
    violations.append("ShelfUITests/ShelfWorldClassUITests.swift: UI search fixture must query text that actually exists in the seeded PDF; technical-token normalization belongs in core fixtures")

if violations:
    print("FAIL: native UI test contract")
    for item in violations:
        print(" -", item)
    sys.exit(1)
print("PASS: native UI test contract (unambiguous controls + real viewport gesture driver).")
