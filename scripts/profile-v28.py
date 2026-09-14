#!/usr/bin/env python3
from pathlib import Path
import subprocess, os, sys
root = Path(__file__).resolve().parent.parent
os.chdir(root)
build = root / '.build/v28-results'
out = root / 'docs/v28.1/performance'
out.mkdir(parents=True, exist_ok=True)
dev = Path('/Applications/Xcode.app/Contents/Developer')
command = [str(dev/'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'), '-swift-version', '5', '-sdk', str(dev/'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'), '-module-cache-path', str(build/'modules'), '-parse-as-library', '-I', str(build), '-L', str(build), '-lShelfCore', '-Xlinker', '-rpath', '-Xlinker', str(build), 'scripts/v28-performance.swift', '-o', str(build/'performance')]
env = dict(os.environ, TMPDIR=str(build))
subprocess.run(command, env=env, check=True)
name = sys.argv[1] if len(sys.argv)>1 else 'optimized'
with (out/(name+'.log')).open('w') as log:
    subprocess.run([str(build/'performance'), name], env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
print(out/(name+'.json'))
