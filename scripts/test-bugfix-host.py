#!/usr/bin/env python3
"""Targeted real XCTest on macOS, plus the actual PDFKit packet replay. No model claim."""
import os
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
os.chdir(root)
build = root / '.build/bugfix-20260914'
proof = root / 'docs/design/bugfix-20260914'
build.mkdir(parents=True, exist_ok=True)
proof.mkdir(parents=True, exist_ok=True)
dev = Path('/Applications/Xcode.app/Contents/Developer')
swift = dev / 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'
platform = dev / 'Platforms/MacOSX.platform/Developer'
sdk = platform / 'SDKs/MacOSX.sdk'
framework = platform / 'Library/Frameworks'
lib = platform / 'usr/lib'
env = dict(os.environ, TMPDIR=str(build), DYLD_FRAMEWORK_PATH=str(platform / 'Library/PrivateFrameworks'))
base = [str(swift), '-swift-version', '5', '-sdk', str(sdk), '-module-cache-path', str(build / 'modules')]

def run(name, command):
    with (proof / (name + '.log')).open('w') as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, env=env)
    print(name, 'PASS' if result.returncode == 0 else 'FAIL', flush=True)
    if result.returncode:
        print((proof / (name + '.log')).read_text()[-7000:])
        sys.exit(result.returncode)

sources = sorted((root / 'Packages/ShelfCore/Sources/ShelfCore').rglob('*.swift'))
run('core-build', base + ['-emit-library', '-emit-module', '-enable-testing', '-module-name', 'ShelfCore',
    '-emit-module-path', str(build / 'ShelfCore.swiftmodule'), '-o', str(build / 'libShelfCore.dylib')] + list(map(str, sources)))
files = sorted((root / 'Packages/ShelfCore/Tests/ShelfCoreTests').rglob('*.swift'))
classes = [name for f in files for name in re.findall(r'class (\w+): XCTestCase', f.read_text())]
if os.environ.get('LEU_HOST_TEST_CLASSES'):
    classes = [c for c in classes if re.search(os.environ['LEU_HOST_TEST_CLASSES'], c)]
main = 'import XCTest\nimport Foundation\nlet suite = XCTestSuite(name: "ShelfCore full bugfix regression")\n'
main += '\n'.join(name + '.defaultTestSuite.tests.forEach(suite.addTest)' for name in classes)
main += '\nsuite.run()\nlet result = suite.testRun!\nprint("EXECUTED: \\(result.executionCount), FAILURES: \\(result.totalFailureCount)")\nexit(result.hasSucceeded && result.executionCount > 0 ? 0 : 1)\n'
(build / 'main.swift').write_text(main)
link = ['-I', str(build), '-I', str(lib), '-L', str(build), '-L', str(lib), '-lShelfCore', '-F', str(framework)]
for path in [build, framework, lib, platform / 'Library/PrivateFrameworks']:
    link += ['-Xlinker', '-rpath', '-Xlinker', str(path)]
run('test-build', base + link + list(map(str, files)) + [str(build / 'main.swift'), '-o', str(build / 'contract-tests')])
run('deterministic-tests', [str(build / 'contract-tests')])
print('Selected ShelfCore host XCTest passed; inspect deterministic-tests.log for actual counts.' if os.environ.get('LEU_HOST_TEST_CLASSES') else 'Full ShelfCore host XCTest passed; inspect deterministic-tests.log for actual counts.')
