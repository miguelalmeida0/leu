#!/usr/bin/env python3
"""V24 privacy boundary: knowledge/learning remain offline; speech inference is local after an explicit asset install."""
from pathlib import Path
import re, sys
ROOT=Path(__file__).resolve().parents[1]
paths=[ROOT/'Shelf/Knowledge',ROOT/'Shelf/Learning',ROOT/'Shelf/Features/ExplainLikeTen',
       ROOT/'Packages/ShelfCore/Sources/ShelfCore/Learning',
       ROOT/'Packages/ShelfCore/Sources/ShelfCore/Knowledge',ROOT/'Packages/ShelfCore/Sources/ShelfCore/Voice']
banned={
    'URLSession':r'\bURLSession\b','Network framework':r'^import\s+Network\b','WebKit':r'^import\s+WebKit\b',
    'OpenAI':r'OpenAI','Anthropic':r'Anthropic','Gemini':r'Gemini','ElevenLabs':r'ElevenLabs',
    'Azure Speech':r'Azure.*Speech|Speech.*Azure','AWS Polly':r'Polly|AWSSpeech','Google cloud speech':r'Google.*Speech|Speech.*Google',
    'vector database':r'Pinecone|Weaviate|Qdrant|Milvus','embedding API':r'embedding(s)?\s*(API|service|endpoint)'
}
violations=[]
for root in paths:
    if not root.exists(): continue
    for p in root.rglob('*.swift'):
        text=p.read_text()
        for label,pattern in banned.items():
            if re.search(pattern,text,re.I|re.M): violations.append(f'{p.relative_to(ROOT)}: {label}')
# The only permitted network path is the explicit, user-triggered Supertonic model installer.
installer=ROOT/'Shelf/Voice/Engine/SupertonicSpeechEngine.swift'
text=installer.read_text()
for token in ['URLSession.shared.download', 'supertone-oss-archive/supertonic-3',
              'aafc6e32416a594460b32413efc49d7fe4ce6d46', 'SupertonicRuntime']:
    if token not in text: violations.append(f'Supertonic installer/runtime contract missing: {token}')
runtime=(ROOT/'Shelf/Voice/Engine/SupertonicRuntime.swift').read_text()
if re.search(r'URLSession|https?://|Network\b|WebKit', runtime, re.I):
    violations.append('Supertonic runtime inference must not access the network')
# Other app voice source files may not perform network I/O.
for p in (ROOT/'Shelf/Voice').rglob('*.swift'):
    if p == installer: continue
    if re.search(r'\bURLSession\b|https?://', p.read_text(), re.I):
        violations.append(f'{p.relative_to(ROOT)}: runtime speech network access is forbidden')
if violations:
    print('Offline/privacy audit failed:\n'+'\n'.join(violations),file=sys.stderr); raise SystemExit(1)
print('PASS: Knowledge and learning remain offline; Supertonic uses one explicit pinned asset download and local ONNX inference thereafter.')
