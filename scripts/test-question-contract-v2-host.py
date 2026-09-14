#!/usr/bin/env python3
"""Targeted real XCTest on macOS, plus the actual PDFKit packet replay. No model claim."""
import os
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
os.chdir(root)
build = root / '.build/question-contract-v2'
proof = root / 'docs/design/question-contract-v2'
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
files = [root / 'Packages/ShelfCore/Tests/ShelfCoreTests/Learning' / f for f in
         ['GroundedQuestionContractTests.swift', 'LearningCandidateValidatorTests.swift']]
count = sum(len(re.findall(r'    func test\w+\(', f.read_text())) for f in files)
main = '''import XCTest
import Foundation
let suite = XCTestSuite(name: "Question Contract V2 + legacy admission")
suite.addTest(GroundedQuestionContractTests.defaultTestSuite)
suite.addTest(LearningCandidateValidatorTests.defaultTestSuite)
suite.run()
let result = suite.testRun!
print("EXECUTED: \\(result.executionCount), FAILURES: \\(result.totalFailureCount)")
exit(result.hasSucceeded && result.executionCount == EXPECTED ? 0 : 1)
'''.replace('EXPECTED', str(count))
(build / 'main.swift').write_text(main)
link = ['-I', str(build), '-I', str(lib), '-L', str(build), '-L', str(lib), '-lShelfCore', '-F', str(framework)]
for path in [build, framework, lib, platform / 'Library/PrivateFrameworks']:
    link += ['-Xlinker', '-rpath', '-Xlinker', str(path)]
run('test-build', base + link + list(map(str, files)) + [str(build / 'main.swift'), '-o', str(build / 'contract-tests')])
run('deterministic-tests', [str(build / 'contract-tests')])
# This replay is evidence, not a fixture replacing production inference.
replay = proof / 'react-replay.swift'
run('replay-build', base + link + [str(replay), '-o', str(build / 'replay')])
run('react-replay', [str(build / 'replay')])
production = list((root / 'Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence').glob('GroundedQuestion*.swift'))
for source in production:
    assert not re.search(r'React|stable key|array index|React Notes|random key', source.read_text(), re.I), source
(proof / 'generic-compiler-check.log').write_text('PASS: no React-specific strings in the generic V2 compiler/realizer/contract.\n')
print(f'{count}/{count} targeted host XCTest PASS; actual PDFKit replay PASS; generic source check PASS.')
