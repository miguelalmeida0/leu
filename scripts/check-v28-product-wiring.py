#!/usr/bin/env python3
"""Static production call-site assertions and syntax parsing; not a UI test."""
from pathlib import Path
import json, subprocess
root = Path(__file__).resolve().parent.parent
out = root / 'docs/v28/productization'
out.mkdir(parents=True, exist_ok=True)
checks = {
 'Study plans immediately while preparation continues': ('Shelf/Learning/LearningModel+Sessions.swift', ['prepareIntelligence()', 'begin(planner.plan']),
 'Background indexing persists the actual bank': ('Shelf/Learning/LearningModel+Intelligence.swift', ['V4GenerationSession(analysis', 'repository.storeV4Batch(batch)', 'completedV4Pages(documentID:']),
 'Teach UI consumes V2 presentation': ('Shelf/Learning/Intelligence/ReaderIntelligenceModel.swift', ['V28TeachPresentation.compare(text', 'feedback = result']),
 'Reader retrieval uses admitted V28 connections': ('Shelf/Learning/Intelligence/ReaderIntelligenceModel.swift', ['learning.libraryIntelligenceCache', 'cache.retrieve(source: source']),
 'Collision uses both bound sources': ('Shelf/Learning/Intelligence/KnowledgeCollisionSheet.swift', ['ConnectionAdmissionV2.validate(connection', 'sources: [connection.sourceA, connection.sourceB]', 'model.viewFact(connection.sourceA', 'model.viewFact(connection.sourceB']),
 'Prediction UI uses tested state machine': ('Shelf/Learning/Intelligence/TryItSheet.swift', ['keyExperiment.predict(choice)', 'keyExperiment.reveal(definition:', 'keyExperiment.state']),
 'Library result opens its validated excerpt': ('Shelf/Learning/Intelligence/ReaderIntelligenceModel.swift', ['item.isCurrent(in:', 'IntelligenceSource(source: item.passage']),
 'PDF route retains document, page and exact quote': ('Shelf/App/AppContainer.swift', ['source.documentID', 'initialPage: source.pageIndex', 'initialSourceText: source.sourceText', 'sourceReturnLabel: returnLabel']),
}
rows = []
for name, (path, tokens) in checks.items():
    text = (root / path).read_text()
    rows.append({'check': name, 'file': path, 'passed': all(t in text for t in tokens)})
model = (root / 'Shelf/Learning/Intelligence/ReaderIntelligenceModel.swift').read_text()
rows.append({'check': 'Teach has no Foundation Models dependency', 'passed': 'proposeAlignments' not in model and 'intelligenceProvider.availability' not in model})
project = (root / 'Shelf.xcodeproj/project.pbxproj').read_text()
rows.append({'check': 'New sheet belongs to Xcode Sources phase', 'passed': 'Intelligence/KnowledgeCollisionSheet.swift in Sources' in project})
swift = '/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'
with (out / 'app-syntax.log').open('w') as log:
    result = subprocess.run([swift, '-frontend', '-parse'] + [str(p) for p in sorted((root / 'Shelf').rglob('*.swift'))], stdout=log, stderr=subprocess.STDOUT)
rows.append({'check': 'Swift syntax parse of all actual app sources', 'passed': result.returncode == 0})
(out / 'production-wiring.json').write_text(json.dumps(rows, indent=2) + '\n')
print('STATIC WIRING + SYNTAX:', sum(r['passed'] for r in rows), '/', len(rows))
assert all(r['passed'] for r in rows), rows
