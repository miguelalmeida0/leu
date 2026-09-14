#!/usr/bin/env python3
"""Hard source-contract gate for Leu V24 semantic/emotional/neural release."""
from pathlib import Path
import re, sys
ROOT=Path(__file__).resolve().parents[1]
issues=[]
def need(cond,msg):
    if not cond: issues.append(msg)
def read(path): return (ROOT/path).read_text(errors='replace')
sem=read('Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticCompiler.swift')
models=read('Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticModels.swift')
questions=read('Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticQuestionCompiler.swift')
engine=read('Packages/ShelfCore/Sources/ShelfCore/Learning/Questions/DeterministicQuestionEngine.swift')
snapshot=read('Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/LearningSnapshot.swift')
repo=read('Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository.swift')
indexer=read('Shelf/Learning/Services/PDFLearningIndexer.swift')
lens=(read('Shelf/Learning/LearningObjectActionSheet.swift') + read('Shelf/Learning/UnderstandingLensSheet.swift')
      + read('Shelf/Learning/UnderstandingLensFact.swift') + read('Shelf/Learning/Components/UnderstandingLensFactRow.swift'))
confidence=read('Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/MemoryModels.swift')
emotion=read('Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/EmotionalModels.swift')
complete=(read('Shelf/Learning/SessionCompleteView.swift') + read('Shelf/Learning/Components/ReleaseSurface.swift'))
sessions=read('Shelf/Learning/LearningModel+Sessions.swift')
voice=read('Shelf/Voice/Engine/SupertonicSpeechEngine.swift')
runtime=read('Shelf/Voice/Engine/SupertonicRuntime.swift')
pbx=read('Shelf.xcodeproj/project.pbxproj')
# Semantic truth/provenance/associations.
for token in ['SemanticProposition','SemanticEvidenceSpan','SemanticAssociation','SemanticTruthClass','SemanticIndex']:
    need(token in models, f'missing semantic type: {token}')
need('truthClass' in models and 'isQuizTruth' in models, 'semantic truth eligibility boundary missing')
need('associations:' in models, 'association graph missing')
need('SemanticCompiler' in sem and 'CodeSemanticParser' in sem, 'semantic/code compiler missing')
need('SemanticQuestionCompiler' in questions and 'semanticFingerprint' in questions, 'semantic question/fingerprint compiler missing')
need('distractors.count >= 2' in questions, 'MCQ fail-closed distractor floor missing')
for forbidden in ['appeared on page','Which term was mentioned','Which item appeared in the document']:
    need(forbidden.lower() not in engine.lower(), f'legacy page-presence question family returned: {forbidden}')
need('SemanticCompiler().compile' in engine and 'SemanticQuestionCompiler().compile' in engine, 'main question engine is not semantic-core backed')
# Persistence/indexing.
need('semanticIndexes' in snapshot and 'semanticIndex:' in repo and 'semanticIndex:' in indexer, 'semantic graph persistence path incomplete')
# Confidence/migration.
for token in ['guessing','unsure','fairlySure','certain','case \"low\"','case \"medium\"','case \"high\"']:
    need(token in confidence, f'four-level confidence/migration contract missing: {token}')
# Lens/source return/cross-source.
need('learning-action-understand' in lens and 'understanding-lens' in lens, 'Understanding Lens entry/surface missing')
need('semanticIndexes.values' in lens and 'evidence.learningSource' in lens and 'queueLensNavigation' in lens, 'Lens must use persisted graph and exact source return')
need('Nothing is generated to fill the gap.' in lens, 'Lens honesty fallback missing')
# Emotional privacy and response behavior.
for token in ['amazing','accomplished','irritated','drained','EmotionalCheckInPolicy']:
    need(token in emotion, f'emotional domain missing: {token}')
for token in ['How did that one feel?','Get it out?','Release','Save my place','Finish here','release-surface']:
    need(token in complete, f'emotional response UI missing: {token}')
need('persistStudyState' in sessions and 'resumeStudyContext' in read('Shelf/Learning/LearningModel.swift'), 'interruption recovery persistence missing')
# Voice is isolated from learning truth.
for token in ['SupertonicAssets','SupertonicSpeechEngine','LeuSpeechEngine','URLSession.shared.download']:
    need(token in voice, f'neural voice integration missing: {token}')
need('OnnxRuntimeBindings' in runtime and 'ORTSession' in runtime, 'local ONNX inference runtime missing')
need('aafc6e32416a594460b32413efc49d7fe4ce6d46' in voice, 'Supertonic model revision is not pinned')
need('onnxruntime-swift-package-manager' in pbx and '"MARKETING_VERSION" = "24.5";' in pbx, 'V24 project/version/dependency contract incomplete')
# Design invariant.
hero=read('Shelf/Features/Library/Components/LibraryHeader.swift')
for forbidden in ['tree','foliage','leaf.fill','leaf.circle']:
    need(forbidden.lower() not in hero[hero.find('struct ContinueReadingHero'):].lower(), f'no-tree resume invariant violated: {forbidden}')
# UI/native acceptance inventory.
ui=read('ShelfUITests/ShelfWorldClassUITests.swift')
for n in range(50,55): need(f'func test{n}' in ui, f'V24 UI acceptance test {n} missing')
if issues:
    print('FAIL: Leu V24 release contract')
    for issue in issues: print(' -',issue)
    raise SystemExit(1)
print('PASS: V24 semantic truth, persistence, certainty, Lens/source-return, emotional privacy/release, interruption, neural voice and no-tree contracts.')
