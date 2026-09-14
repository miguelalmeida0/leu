#!/usr/bin/env python3
"""Add only V27 sources to existing OpenStep groups/phases; keep formatting."""
from pathlib import Path
import hashlib
import re
import subprocess

root = Path(__file__).resolve().parent.parent
project = root / 'Shelf.xcodeproj/project.pbxproj'
text = project.read_text()
def add_members(object_id, key, members):
    global text
    pattern = re.compile(r'(' + object_id + r' /\*[^\n]+\*/ = \{.*?' + key + r' = \()(.*?)(\n\s*\);)', re.S)
    match = pattern.search(text)
    assert match, object_id
    block = match.group(2)
    for member in members:
        if member.split()[0] not in block: block += '\n\t\t\t\t' + member + ','
    text = text[:match.start(2)] + block + text[match.end(2):]
for directory, group, phase, paths in [
    ('Shelf/Learning', 'A20A1E4F9C7731B2D7F0C001', '507A349611DBB42F9CF9069B', sorted((root / 'Shelf/Learning/Intelligence').glob('*.swift'))),
    ('ShelfUITests', 'BBCB595317B18176C53D936B', 'B83A31893509703A61030AA6', [root / 'ShelfUITests/ShelfV27IntelligenceUITests.swift'])]:
    refs, builds = [], []
    for path in paths:
        relative = str(path.relative_to(root / directory))
        ref = hashlib.sha1(('v27-ref-' + relative).encode()).hexdigest()[:24].upper()
        build = hashlib.sha1(('v27-build-' + relative).encode()).hexdigest()[:24].upper()
        if ref not in text:
            text = text.replace('/* End PBXFileReference section */', f'\t\t{ref} /* {relative} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{relative}"; sourceTree = "<group>"; }};\n/* End PBXFileReference section */')
            text = text.replace('/* End PBXBuildFile section */', f'\t\t{build} /* {relative} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {relative} */; }};\n/* End PBXBuildFile section */')
        refs.append(f'{ref} /* {relative} */'); builds.append(f'{build} /* {relative} in Sources */')
    add_members(group, 'children', refs); add_members(phase, 'files', builds)
# Independent app/test containers protect canonical physical acceptance data.
text = text.replace('dev.shelf.personal', 'dev.shelf.v27')
project.write_text(text)
subprocess.run(['plutil', '-lint', str(project)], check=True)
