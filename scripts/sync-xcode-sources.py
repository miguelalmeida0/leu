#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import hashlib, json, re, sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'Shelf.xcodeproj/project.pbxproj'
MANIFEST = ROOT / 'docs/internal/evidence/project-manifest.json'

SHELF_GROUP = '91BC77E451450E1E31E5FDBA'
READER_GROUP = 'C4A18DEBF678F82D4FED4D64'
UI_GROUP = 'BBCB595317B18176C53D936B'
UNIT_GROUP = 'B6982961E289F33EEC3B17F4'
APP_SOURCES_PHASE = '507A349611DBB42F9CF9069B'
UNIT_SOURCES_PHASE = 'C58E1308FCED550A39C0D785'
UI_SOURCES_PHASE = 'B83A31893509703A61030AA6'
LEARNING_GROUP = 'A20A1E4F9C7731B2D7F0C001'
KNOWLEDGE_GROUP = 'A21A1E4F9C7731B2D7F0C002'
VOICE_GROUP = 'A21A1E4F9C7731B2D7F0C003'
RECONSTRUCTION_GROUP = 'A25000000000000000000001'
DEVELOPMENT_GROUP = 'A25000000000000000000002'
DELETED_OBJECTS = {
    'C90693116F4D6FFE3A85A43B', # PhysicalPageMatcher.swift
    '5E6090C1F6F1154EFFDED3C8', # build file
    'BEEF054E0D80151EF6E61B55', # PhysicalPageCaptureView.swift
    '3C915974937DE5BB3D39D9D0', # build file
}


def stable_id(kind: str, path: str) -> str:
    # V24 initially registered these with explicit IDs; reuse them instead of
    # adding duplicate file references/build inputs during a later synchronization.
    adopted = {
        'Shelf/Voice/Engine/SupertonicRuntime.swift': ('A24000000000000000000001', 'A24000000000000000000002'),
        'Shelf/Voice/Engine/SupertonicSpeechEngine.swift': ('A24000000000000000000003', 'A24000000000000000000004'),
    }
    if path in adopted:
        return adopted[path][0 if kind == 'ref' else 1]
    return hashlib.sha1(f'shelf-v20|{kind}|{path}'.encode()).hexdigest().upper()[:24]


def object_block(ref: str, path: str, file_type: str = 'sourcecode.swift') -> str:
    return (f'        "{ref}" = {{\n'
            f'            "isa" = "PBXFileReference";\n'
            f'            "lastKnownFileType" = "{file_type}";\n'
            f'            "path" = "{path}";\n'
            f'            "sourceTree" = "<group>";\n'
            f'        }};\n')


def build_block(build: str, ref: str) -> str:
    return (f'        "{build}" = {{\n'
            f'            "isa" = "PBXBuildFile";\n'
            f'            "fileRef" = "{ref}";\n'
            f'        }};\n')


def replace_children(text: str, object_id: str, additions: list[str], removals: set[str] = set()) -> str:
    pattern = re.compile(rf'("{re.escape(object_id)}" = \{{.*?"children" = \()(.*?)(\n\s*\);)', re.S)
    m = pattern.search(text)
    if not m:
        raise RuntimeError(f'Cannot find children for {object_id}')
    current = re.findall(r'"([A-F0-9]{24})"', m.group(2))
    current = [x for x in current if x not in removals]
    for item in additions:
        if item not in current:
            current.append(item)
    indent = '                '
    body = '\n' + ''.join(f'{indent}"{item}",\n' for item in current).rstrip('\n')
    return text[:m.start(2)] + body + text[m.end(2):]


def replace_files(text: str, object_id: str, additions: list[str], removals: set[str] = set()) -> str:
    pattern = re.compile(rf'("{re.escape(object_id)}" = \{{.*?"files" = \()(.*?)(\n\s*\);)', re.S)
    m = pattern.search(text)
    if not m:
        raise RuntimeError(f'Cannot find files for {object_id}')
    current = re.findall(r'"([A-F0-9]{24})"', m.group(2))
    current = [x for x in current if x not in removals]
    for item in additions:
        if item not in current:
            current.append(item)
    indent = '                '
    body = '\n' + ''.join(f'{indent}"{item}",\n' for item in current).rstrip('\n')
    return text[:m.start(2)] + body + text[m.end(2):]


def remove_simple_object(text: str, object_id: str) -> str:
    # The obsolete objects are PBXFileReference/PBXBuildFile blocks with no nested braces.
    return re.sub(rf'\n\s*"{re.escape(object_id)}" = \{{.*?\n\s*\}};', '', text, count=1, flags=re.S)


def main() -> int:
    text = PROJECT.read_text()
    # Remove old Vision/camera source objects and memberships first.
    text = replace_children(text, '238F67040B36075AA6524B7F', [], {'BEEF054E0D80151EF6E61B55'})
    text = replace_children(text, 'DC519F55E9055FAE5419382D', [], {'C90693116F4D6FFE3A85A43B'})
    text = replace_files(text, APP_SOURCES_PHASE, [], {'3C915974937DE5BB3D39D9D0', '5E6090C1F6F1154EFFDED3C8'})
    for obj in DELETED_OBJECTS:
        text = remove_simple_object(text, obj)

    learning_paths = sorted(str(p.relative_to(ROOT / 'Shelf/Learning')) for p in (ROOT / 'Shelf/Learning').rglob('*.swift'))
    reader_paths = ['ReaderModel+BlindPage.swift', 'ReaderModel+Learning.swift', 'ReaderModel+Lens.swift']
    knowledge_paths = sorted(str(p.relative_to(ROOT / 'Shelf/Knowledge')) for p in (ROOT / 'Shelf/Knowledge').rglob('*.swift'))
    voice_paths = sorted(str(p.relative_to(ROOT / 'Shelf/Voice')) for p in (ROOT / 'Shelf/Voice').rglob('*.swift'))
    unit_paths = ['LearningIndexIntegrationTests.swift', 'KnowledgeIntegrationTests.swift', 'VoiceCatalogTests.swift', 'PDFReconstructionV25Tests.swift', 'LearningRealModelP0Tests.swift', 'PDFReadFurnitureTests.swift']
    unit_paths += ['SessionExperienceTests.swift', 'RecallSessionStateTests.swift', 'QuestionContractV2IntegrationTests.swift', 'BugfixIntegrationTests.swift']
    unit_paths += sorted(p.name for p in (ROOT / 'ShelfTests').glob('Expl*.swift'))
    ui_paths = ["ShelfStudyHomeUITests.swift", 'ShelfLearningOSUITests.swift', 'ShelfWorldClassUITests.swift',
                'StudyInteractionSupport.swift', 'ShelfStudyInteractionUITests.swift', 'V24InteractionSupport.swift', 'ReleaseInteractionSupport.swift', 'ShelfEmotionalFlowUITests.swift', 'ShelfRecoveryV25UITests.swift', 'ShelfSourceRecoveryP0UITests.swift']
    ui_paths += ['ShelfSessionExperienceUITests.swift']
    ui_paths += sorted(p.name for p in (ROOT / 'ShelfUITests').glob('ShelfExpl*.swift'))

    new_objects = []
    design_refs = []
    learning_refs = []
    app_builds = []
    for rel in ['LeuAccessibleSurfaces.swift', 'LeuPrimaryButtonStyle.swift']:
        full = f'Shelf/DesignSystem/{rel}'
        ref, build = stable_id('ref', full), stable_id('build', full)
        design_refs.append(ref); app_builds.append(build)
        if f'"{ref}" = {{' not in text:
            new_objects += [object_block(ref, rel), build_block(build, ref)]
    for rel in learning_paths:
        full = f'Shelf/Learning/{rel}'
        ref, build = stable_id('ref', full), stable_id('build', full)
        learning_refs.append(ref); app_builds.append(build)
        if f'"{ref}" = {{' not in text:
            new_objects += [object_block(ref, rel), build_block(build, ref)]

    knowledge_refs = []
    for rel in knowledge_paths:
        full = f'Shelf/Knowledge/{rel}'
        ref, build = stable_id('ref', full), stable_id('build', full)
        knowledge_refs.append(ref); app_builds.append(build)
        if f'"{ref}" = {{' not in text:
            new_objects += [object_block(ref, rel), build_block(build, ref)]

    voice_refs = []
    for rel in voice_paths:
        full = f'Shelf/Voice/{rel}'
        ref, build = stable_id('ref', full), stable_id('build', full)
        voice_refs.append(ref); app_builds.append(build)
        if f'"{ref}" = {{' not in text:
            new_objects += [object_block(ref, rel), build_block(build, ref)]

    reconstruction_refs = []
    for rel in ['PDFSpatialText.swift', 'PDFLineGrouper.swift', 'PDFBlockClassifier.swift', 'PDFTextReconstructor.swift', 'PDFDocumentFurniture.swift']:
        full = f'Shelf/Infrastructure/PDF/{rel}'
        ref, build = stable_id('ref', full), stable_id('build', full)
        reconstruction_refs.append(ref); app_builds.append(build)
        if f'"{ref}" = {{' not in text:
            new_objects += [object_block(ref, rel), build_block(build, ref)]
    development_refs = []
    for path in sorted((ROOT / 'Shelf/Development').glob('*.swift')):
        full = str(path.relative_to(ROOT))
        ref, build = stable_id('ref', full), stable_id('build', full)
        development_refs.append(ref); app_builds.append(build)
        if f'"{ref}" = {{' not in text:
            new_objects += [object_block(ref, path.name), build_block(build, ref)]

    explanation_group = stable_id('group', 'Shelf/Features/ExplainLikeTen')
    explanation_refs = []
    for path in sorted((ROOT / 'Shelf/Features/ExplainLikeTen').glob('*.swift')):
        full = str(path.relative_to(ROOT))
        ref, build = stable_id('ref', full), stable_id('build', full)
        explanation_refs.append(ref); app_builds.append(build)
        if f'"{ref}" = {{' not in text:
            new_objects += [object_block(ref, path.name), build_block(build, ref)]
    prompt_path = 'Shelf/Features/ExplainLikeTen/RUNTIME_EXPLANATION_PROMPT.txt'
    prompt_ref, prompt_build = stable_id('ref', prompt_path), stable_id('build', prompt_path)
    explanation_refs.append(prompt_ref)
    if f'"{prompt_ref}" = {{' not in text:
        new_objects += [object_block(prompt_ref, Path(prompt_path).name, 'text'), build_block(prompt_build, prompt_ref)]

    reader_refs = []
    for rel in reader_paths:
        full = f'Shelf/Features/Reader/{rel}'
        ref, build = stable_id('ref', full), stable_id('build', full)
        reader_refs.append(ref); app_builds.append(build)
        if f'"{ref}" = {{' not in text:
            new_objects += [object_block(ref, rel), build_block(build, ref)]

    unit_refs, unit_builds = [], []
    for rel in unit_paths:
        full = f'ShelfTests/{rel}'
        ref, build = stable_id('ref', full), stable_id('build', full)
        unit_refs.append(ref); unit_builds.append(build)
        if f'"{ref}" = {{' not in text:
            new_objects += [object_block(ref, rel), build_block(build, ref)]

    ui_refs, ui_builds = [], []
    for rel in ui_paths:
        full = f'ShelfUITests/{rel}'
        ref, build = stable_id('ref', full), stable_id('build', full)
        ui_refs.append(ref); ui_builds.append(build)
        if f'"{ref}" = {{' not in text:
            new_objects += [object_block(ref, rel), build_block(build, ref)]

    def append_group(group_id: str, path: str, refs: list[str]) -> None:
        nonlocal text, new_objects
        if f'"{group_id}" = {{' in text:
            return
        group = (f'        "{group_id}" = {{\n'
                 f'            "isa" = "PBXGroup";\n'
                 f'            "children" = (\n' +
                 ''.join(f'                "{ref}",\n' for ref in refs) +
                 f'            );\n'
                 f'            "path" = "{path}";\n'
                 f'            "sourceTree" = "<group>";\n'
                 f'        }};\n')
        new_objects.append(group)

    append_group(KNOWLEDGE_GROUP, 'Knowledge', knowledge_refs)
    append_group(VOICE_GROUP, 'Voice', voice_refs)
    append_group(RECONSTRUCTION_GROUP, 'Infrastructure/PDF', reconstruction_refs)
    append_group(DEVELOPMENT_GROUP, 'Development', development_refs)
    append_group(explanation_group, 'Features/ExplainLikeTen', explanation_refs)

    if f'"{LEARNING_GROUP}" = {{' not in text:
        group = (f'        "{LEARNING_GROUP}" = {{\n'
                 f'            "isa" = "PBXGroup";\n'
                 f'            "children" = (\n' +
                 ''.join(f'                "{ref}",\n' for ref in learning_refs) +
                 f'            );\n'
                 f'            "path" = "Learning";\n'
                 f'            "sourceTree" = "<group>";\n'
                 f'        }};\n')
        new_objects.append(group)

    marker = '    "objects" = {\n'
    if new_objects:
        text = text.replace(marker, marker + ''.join(new_objects), 1)

    text = replace_children(text, SHELF_GROUP, [LEARNING_GROUP, KNOWLEDGE_GROUP, VOICE_GROUP, RECONSTRUCTION_GROUP, DEVELOPMENT_GROUP, explanation_group])
    text = replace_children(text, explanation_group, explanation_refs)
    text = replace_children(text, '919A3B1BFCD57D44EF6E1DB7', design_refs)
    text = replace_children(text, RECONSTRUCTION_GROUP, reconstruction_refs)
    text = replace_children(text, DEVELOPMENT_GROUP, development_refs)
    text = replace_children(text, LEARNING_GROUP, learning_refs)
    text = replace_children(text, KNOWLEDGE_GROUP, knowledge_refs)
    text = replace_children(text, VOICE_GROUP, voice_refs)
    text = replace_children(text, READER_GROUP, reader_refs)
    text = replace_children(text, UNIT_GROUP, unit_refs)
    text = replace_children(text, UI_GROUP, ui_refs)
    text = replace_files(text, APP_SOURCES_PHASE, app_builds)
    text = replace_files(text, UNIT_SOURCES_PHASE, unit_builds)
    text = replace_files(text, UI_SOURCES_PHASE, ui_builds)
    text = replace_files(text, '4C29BBC16528FEA9E858725B', [prompt_build])
    PROJECT.write_text(text)

    manifest = json.loads(MANIFEST.read_text())
    manifest['appSources'] = sorted(str(p.relative_to(ROOT)) for p in (ROOT / 'Shelf').rglob('*.swift'))
    manifest['unitTestSources'] = sorted(str(p.relative_to(ROOT)) for p in (ROOT / 'ShelfTests').rglob('*.swift'))
    manifest['uiTestSources'] = sorted(str(p.relative_to(ROOT)) for p in (ROOT / 'ShelfUITests').rglob('*.swift'))
    if prompt_path not in manifest['resources']: manifest['resources'].append(prompt_path)
    manifest['generatedWith'] = 'scripts/sync-xcode-sources.py · Shelf Connected Learning + Voice V21'
    MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    print(f'PASS: synced {len(manifest["appSources"])} app, {len(manifest["unitTestSources"])} unit-test, {len(manifest["uiTestSources"])} UI-test Swift files.')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
