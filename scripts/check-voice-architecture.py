#!/usr/bin/env python3
from pathlib import Path
import re,sys
ROOT=Path(__file__).resolve().parents[1]
required=[
'Packages/ShelfCore/Sources/ShelfCore/Voice/Domain/SpeechModels.swift',
'Packages/ShelfCore/Sources/ShelfCore/Voice/Compilation/SpeechCompiler.swift',
'Packages/ShelfCore/Sources/ShelfCore/Voice/Normalization/TechnicalSpeechNormalizer.swift',
'Packages/ShelfCore/Sources/ShelfCore/Voice/Normalization/CodeSpeechNormalizer.swift',
'Packages/ShelfCore/Sources/ShelfCore/Voice/Prosody/SpeechProsodyPlanner.swift',
'Packages/ShelfCore/Sources/ShelfCore/Voice/Pronunciation/PronunciationDictionary.swift',
'Shelf/Voice/Voices/VoiceCatalog.swift','Shelf/Voice/Engine/AppleSpeechEngine.swift',
'Shelf/Voice/Playback/AudioSessionCoordinator.swift','Shelf/Voice/Playback/RemoteCommandCoordinator.swift','Shelf/Voice/UI/VoiceSettingsSheet.swift']
missing=[p for p in required if not (ROOT/p).exists()]
if missing: print('Voice architecture missing:\n'+'\n'.join(missing),file=sys.stderr); raise SystemExit(1)
# Raw AVSpeechUtterance construction is allowed only in the low-level Apple engine.
viol=[]
for p in (ROOT/'Shelf').rglob('*.swift'):
    if p.name=='AppleSpeechEngine.swift': continue
    if 'AVSpeechUtterance(' in p.read_text(): viol.append(str(p.relative_to(ROOT)))
if viol: print('Raw TTS bypass detected: '+', '.join(viol),file=sys.stderr); raise SystemExit(1)
controller=(ROOT/'Shelf/Infrastructure/PDF/ReaderSpeechController.swift').read_text()
for token in ['SpeechCompiler','SpeechDocument','segment.source.sourceText','segment.spokenText','lastStartLatencyMilliseconds']:
    if token not in controller: print('Reader speech coordinator missing '+token,file=sys.stderr); raise SystemExit(1)
catalog=(ROOT/'Shelf/Voice/Voices/VoiceCatalog.swift').read_text()
for token in ['.premium','.enhanced','speechVoices()']:
    if token not in catalog: print('Voice quality ranking missing '+token,file=sys.stderr); raise SystemExit(1)

remote=(ROOT/'Shelf/Voice/Playback/RemoteCommandCoordinator.swift').read_text()
for token in ['MPRemoteCommandCenter','skipForwardCommand','skipBackwardCommand','MPNowPlayingInfoCenter']:
    if token not in remote: print('Background/remote transport missing '+token,file=sys.stderr); raise SystemExit(1)
plist=(ROOT/'Shelf/Resources/Info.plist').read_text()
if 'UIBackgroundModes' not in plist or '<string>audio</string>' not in plist:
    print('Shelf Voice background audio capability is missing from Info.plist',file=sys.stderr); raise SystemExit(1)
print('PASS: Shelf Voice uses a source-mapped compiler, quality-ranked Apple voices, and native background/remote transport.')
