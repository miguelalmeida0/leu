#!/usr/bin/env python3
"""Focused actual-PDF results. No simulator or Foundation Models invocation."""
from pathlib import Path
import os, subprocess, sys
root = Path(__file__).resolve().parent.parent
os.chdir(root)
build = root / '.build/v28-results'
out = root / 'docs/v28/results-sprint'
build.mkdir(parents=True, exist_ok=True); out.mkdir(parents=True, exist_ok=True)
dev = Path('/Applications/Xcode.app/Contents/Developer')
platform = dev / 'Platforms/MacOSX.platform/Developer'
base = [str(dev / 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'), '-swift-version', '5', '-sdk', str(platform / 'SDKs/MacOSX.sdk'), '-module-cache-path', str(build / 'modules')]
env = dict(os.environ, TMPDIR=str(build))
def run(name, command):
    with (out / (name + '.log')).open('w') as log:
        result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT)
    print(name, 'PASS' if result.returncode == 0 else 'FAIL', flush=True)
    if result.returncode:
        print((out / (name + '.log')).read_text()[-8000:]); sys.exit(result.returncode)
if '--reuse-core' not in sys.argv:
    run('core-build', base + ['-emit-library', '-emit-module', '-enable-testing', '-module-name', 'ShelfCore', '-emit-module-path', str(build / 'ShelfCore.swiftmodule'), '-o', str(build / 'libShelfCore.dylib')] + list(map(str, sorted((root / 'Packages/ShelfCore/Sources/ShelfCore').rglob('*.swift')))))
run('results-build', base + ['-parse-as-library', '-I', str(build), '-L', str(build), '-lShelfCore', '-Xlinker', '-rpath', '-Xlinker', str(build), 'scripts/v28-results.swift', '-o', str(build / 'results')])
run('results', [str(build / 'results')])
print((out / 'results.log').read_text(), flush=True)
