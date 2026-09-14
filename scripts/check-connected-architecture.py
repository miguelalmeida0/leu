#!/usr/bin/env python3
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
required=[
'Packages/ShelfCore/Sources/ShelfCore/Knowledge/Domain/KnowledgePassage.swift',
'Packages/ShelfCore/Sources/ShelfCore/Knowledge/Domain/KnowledgeConcept.swift',
'Packages/ShelfCore/Sources/ShelfCore/Knowledge/Domain/KnowledgeConnection.swift',
'Packages/ShelfCore/Sources/ShelfCore/Knowledge/Domain/TopicChain.swift',
'Packages/ShelfCore/Sources/ShelfCore/Knowledge/Domain/KnowledgeSnapshot.swift',
'Packages/ShelfCore/Sources/ShelfCore/Knowledge/Indexing/BM25Index.swift',
'Packages/ShelfCore/Sources/ShelfCore/Knowledge/Indexing/ConnectionRanker.swift',
'Packages/ShelfCore/Sources/ShelfCore/Knowledge/Indexing/PassageReanchorer.swift',
'Packages/ShelfCore/Sources/ShelfCore/Knowledge/Persistence/KnowledgeRepository.swift',
'Shelf/Knowledge/KnowledgeModel.swift',
'Shelf/Knowledge/Components/ConnectedPassageSheet.swift',
'Shelf/Knowledge/Components/TopicChainScreens.swift']
missing=[p for p in required if not (ROOT/p).exists()]
if missing: print('Connected architecture missing:\n'+'\n'.join(missing),file=sys.stderr); raise SystemExit(1)
# User knowledge must be physically separate from derived index state.
snapshot=(ROOT/'Packages/ShelfCore/Sources/ShelfCore/Knowledge/Domain/KnowledgeSnapshot.swift').read_text()
for token in ['indexRecords','confirmedConnections','topicChains','userBindings']:
    if token not in snapshot: print('Missing knowledge separation token '+token,file=sys.stderr); raise SystemExit(1)
rank=(ROOT/'Packages/ShelfCore/Sources/ShelfCore/Knowledge/Indexing/ConnectionRanker.swift').read_text()
for token in ['BM25Index','sharedConcept','sharedPhrases','minimumScore','genericOnlyPenalty']:
    if token not in rank: print('Ranking quality contract missing '+token,file=sys.stderr); raise SystemExit(1)
repo=(ROOT/'Packages/ShelfCore/Sources/ShelfCore/Knowledge/Persistence/KnowledgeRepository.swift').read_text()
for token in ['clearDerivedIndex','repairUserKnowledge','unresolvedTombstones','requiresRecovery']:
    if token not in repo: print('Reindex safety contract missing '+token,file=sys.stderr); raise SystemExit(1)

model='\n'.join(p.read_text() for p in sorted((ROOT/'Shelf/Knowledge').glob('KnowledgeModel*.swift')))
for token in ['addPassages','removeConnection','createChain']:
    if token not in model: print('Topic Chain / durable link editing contract missing '+token,file=sys.stderr); raise SystemExit(1)
sheet=(ROOT/'Shelf/Knowledge/Components/ConnectedPassageSheet.swift').read_text()
for token in ['Remove connection','Save connection','Refine']:
    if token not in sheet: print('Connected-passage product flow missing '+token,file=sys.stderr); raise SystemExit(1)
print('PASS: connected-library architecture, ranking floor, one-action connection saving, Trails refinement and reindex recovery contracts.')
