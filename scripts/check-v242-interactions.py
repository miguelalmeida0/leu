#!/usr/bin/env python3
"""Regression source policies, not a substitute for Xcode or accessibility runtime tests."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
SURFACES={
 'Shelf/Features/Reader/ReaderScreen.swift':['reader-screen'],
 'Shelf/Learning/StudySessionScreen.swift':['study-session-screen'],
 'Shelf/Learning/QuestionCardView.swift':['question-card'],
 'Shelf/Learning/RecallCardView.swift':['recall-card'],
 'Shelf/Learning/SessionCompleteView.swift':['session-complete-screen','emotional-check-in'],
 'Shelf/Learning/Components/ReleaseSurface.swift':['release-surface'],
 'Shelf/Learning/UnderstandingLensSheet.swift':['understanding-lens']}

def violations(root=ROOT, overrides=None):
    overrides=overrides or {}
    def read(name): return overrides.get(name,(root/name).read_text())
    issues=[]
    for path, identifiers in SURFACES.items():
        text=read(path)
        for identifier in identifiers:
            if f'.accessibilityIdentifier("{identifier}")' in text:
                issues.append(f'{path}: inherited container identifier returned: {identifier}')
            if f'UITestFrameProbe(identifier: "{identifier}")' not in text:
                issues.append(f'{path}: missing isolated geometry marker: {identifier}')
    top=read('Shelf/Features/Reader/Components/ReaderTopBar.swift')
    if '.accessibilityElement(children: .ignore)' in top:
        issues.append('Reader return must preserve native Button semantics')
    lens=read('Shelf/Learning/UnderstandingLensSheet.swift')
    if 'model.openSource(' in lens or 'queueLensNavigation' not in lens:
        issues.append('Lens must preserve its origin, not use the Study question-source route')
    route=read('Shelf/App/RootView.swift')
    for token in ['didRestoreStudyOnLaunch', 'primaryArea = .learn', 'route.study.restored', 'restoreLens: destination.restoreLens']:
        if token not in route: issues.append('Root restore contract missing: '+token)
    recovery=read('Shelf/Learning/LearningModel+Recovery.swift')
    for token in ['await previous?.value','saveStudyCheckpoint(session: session, context: context)',
                  'studySaveRevision == revision','studySaveError = error.localizedDescription','context.questionID == question.id']:
        if token not in recovery: issues.append('Durable ordered recovery contract missing: '+token)
    sessions=read('Shelf/Learning/LearningModel+Sessions.swift')
    for token in ['try? await repository.saveSession', 'Task { try? await repository.saveResumeStudyContext']:
        if token in sessions: issues.append('Unordered/silent study checkpoint write returned')
    ui=read('ShelfUITests/V24InteractionSupport.swift')
    for token in ['settingsViewport(form)', 'upward: false','viewport.contains(button.frame)',
                  'tapStudyButton("question-option-0"', 'tapStudyButton("commit-answer"',
                  'XCTNSPredicateExpectation(predicate: advanced', 'waitForStudySave']:
        if token not in ui: issues.append('UI journey must navigate/verify actual controls: '+token)
    if 'RunLoop.current.run' in ui: issues.append('Fixed sleeps must not replace transition assertions')
    return issues

def main():
    issues=violations()
    if issues:
        print('FAIL: V24.2 interaction/recovery source policy');print('\n'.join(' - '+x for x in issues));return 1
    print('PASS: isolated identifiers, Lens round-trip, launch restoration, ordered checkpoints and visible native-control journeys')
    return 0
if __name__=='__main__': raise SystemExit(main())
