#!/usr/bin/env python3
"""Seven production-core integration journeys. Reuses the preserved core build."""
from pathlib import Path
import os, subprocess, sys
root = Path(__file__).resolve().parent.parent
os.chdir(root)
build = root / '.build/v28-results'
out = root / 'docs/v28/productization'
out.mkdir(parents=True, exist_ok=True)
dev = Path('/Applications/Xcode.app/Contents/Developer')
base = [str(dev / 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'), '-swift-version', '5',
        '-sdk', str(dev / 'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'), '-module-cache-path', str(build / 'modules')]
for name, command in [
    ('integration-build', base + ['-parse-as-library', '-I', str(build), '-L', str(build), '-lShelfCore',
     '-Xlinker', '-rpath', '-Xlinker', str(build), 'scripts/v28-product-integration.swift', '-o', str(build / 'product-integration')]),
    ('integration', [str(build / 'product-integration')])]:
    with (out / (name + '.log')).open('w') as log:
        result = subprocess.run(command, env=dict(os.environ, TMPDIR=str(build)), stdout=log, stderr=subprocess.STDOUT)
    print(name, 'PASS' if result.returncode == 0 else 'FAIL', flush=True)
    print((out / (name + '.log')).read_text()[-6000:], flush=True)
    if result.returncode: sys.exit(result.returncode)
