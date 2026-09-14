#!/usr/bin/env python3
from pathlib import Path
import subprocess, os
root = Path(__file__).resolve().parent.parent
os.chdir(root)
build = root / '.build/v28-results'
dev = Path('/Applications/Xcode.app/Contents/Developer')
env = dict(os.environ, TMPDIR=str(build))
base = [str(dev/'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'), '-swift-version', '5', '-sdk', str(dev/'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'), '-module-cache-path', str(build/'modules')]
subprocess.run(base + ['-parse-as-library', '-I', str(build), '-L', str(build), '-lShelfCore', '-Xlinker', '-rpath', '-Xlinker', str(build), 'scripts/v28-instant-tests.swift', '-o', str(build/'instant-tests')], env=env, check=True)
with (root/'docs/v28.1/performance/incremental-tests.log').open('w') as log:
    subprocess.run([str(build/'instant-tests')], env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
print('Incremental and cache tests PASS')
