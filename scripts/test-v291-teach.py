#!/usr/bin/env python3
"""Actual production adapter and persistence execution on host; not iOS UI proof."""
from pathlib import Path
import os, subprocess
root = Path(__file__).resolve().parent.parent
os.chdir(root)
dev = Path('/Applications/Xcode.app/Contents/Developer')
build = root/'.build/v291-teach'
build.mkdir(parents=True, exist_ok=True)
out = root/'evidence/v29.1/after'
core, reasoning = root/'.build/v28-results', root/'.build/v29-host'
base = [str(dev/'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'), '-swift-version', '5', '-sdk', str(dev/'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'), '-module-cache-path', str(build/'modules')]
link = []
for path, module in [(core, 'ShelfCore'), (reasoning, 'LeuReasoningCore')]:
    link += ['-I',str(path),'-L',str(path),'-l'+module,'-Xlinker','-rpath','-Xlinker',str(path)]
for name, command in [('adapter-build', base+link+['-parse-as-library','Shelf/Learning/Intelligence/TeachReasoningAdapter.swift','scripts/v291-teach-integration.swift','-o',str(build/'journey')]), ('adapter-journey',[str(build/'journey')])]:
    with (out/(name+'.log')).open('w') as log:
        result = subprocess.run(command, env=dict(os.environ,TMPDIR=str(build)), stdout=log, stderr=subprocess.STDOUT)
    print(name, 'PASS' if result.returncode == 0 else 'FAIL', flush=True)
    print((out/(name+'.log')).read_text()[-5000:], flush=True)
    if result.returncode: raise SystemExit(result.returncode)
