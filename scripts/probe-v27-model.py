#!/usr/bin/env python3
"""Compile and invoke the actual on-device provider on macOS. No mocks."""
from pathlib import Path
import os, subprocess
root = Path(__file__).resolve().parent.parent
build = root / '.build/v27'
proof = root / 'docs/v27/evidence'
dev = Path('/Applications/Xcode.app/Contents/Developer')
platform = dev / 'Platforms/MacOSX.platform/Developer'
env = dict(os.environ, TMPDIR=str(build))
command = [str(dev / 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'), '-swift-version', '5',
    '-sdk', str(platform / 'SDKs/MacOSX.sdk'), '-module-cache-path', str(build / 'modules'), '-parse-as-library',
    '-I', str(build), '-L', str(build), '-lShelfCore', '-Xlinker', '-rpath', '-Xlinker', str(build),
    str(root / 'Shelf/Learning/Services/AppleLearningIntelligenceProvider.swift'),
    str(root / 'Shelf/Learning/Intelligence/AppleLearningIntelligenceProvider+TeachLeu.swift'),
    str(root / 'scripts/v27-model-probe.swift'), '-o', str(build / 'model-probe')]
for name, cmd in [('provider-build', command), ('model-probe', [str(build / 'model-probe')])]:
    with (proof / (name + '.log')).open('w') as log:
        result = subprocess.run(cmd, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=100)
    print(name, result.returncode, flush=True)
    if result.returncode: raise SystemExit(result.returncode)
