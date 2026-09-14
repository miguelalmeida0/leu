#!/usr/bin/env python3
"""Targeted real XCTest on macOS, plus the actual PDFKit packet replay. No model claim."""
import os
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
os.chdir(root)
build = root / '.build/v27'
proof = root / 'docs/v28/evidence/baseline'
build.mkdir(parents=True, exist_ok=True)
proof.mkdir(parents=True, exist_ok=True)
dev = Path('/Applications/Xcode.app/Contents/Developer')
swift = dev / 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'
platform = dev / 'Platforms/MacOSX.platform/Developer'
sdk = platform / 'SDKs/MacOSX.sdk'
framework = platform / 'Library/Frameworks'
lib = platform / 'usr/lib'
env = dict(os.environ, TMPDIR=str(build), V27_TEST_ROOT=str(build), DYLD_FRAMEWORK_PATH=str(platform / 'Library/PrivateFrameworks'))
base = [str(swift), '-swift-version', '5', '-sdk', str(sdk), '-module-cache-path', str(build / 'modules')]

def run(name, command, required=True):
    with (proof / (name + '.log')).open('w') as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, env=env)
    print(name, 'PASS' if result.returncode == 0 else 'FAIL', flush=True)
    if result.returncode:
        print((proof / (name + '.log')).read_text()[-7000:])
        if required: sys.exit(result.returncode)
    return result.returncode == 0

sources = sorted((root / 'Packages/ShelfCore/Sources/ShelfCore').rglob('*.swift'))
if '--reuse-core' not in sys.argv: run('core-build', base + ['-emit-library', '-emit-module', '-enable-testing', '-module-name', 'ShelfCore',
    '-emit-module-path', str(build / 'ShelfCore.swiftmodule'), '-o', str(build / 'libShelfCore.dylib')] + list(map(str, sources)))
files = [root / 'Packages/ShelfCore/Tests/ShelfCoreTests/Learning' / name for name in
    ['V27IntelligenceTests.swift', 'GroundedQuestionContractTests.swift']]
count = sum(len(re.findall(r'    func test\w+\(', f.read_text())) for f in files)
main = '''import XCTest
import Foundation
let suite = XCTestSuite(name: "V27 focused intelligence")
suite.addTest(V27IntelligenceTests.defaultTestSuite)
suite.addTest(GroundedQuestionContractTests.defaultTestSuite)
suite.run()
let result = suite.testRun!
print("EXECUTED: \\(result.executionCount), FAILURES: \\(result.totalFailureCount)")
exit(result.hasSucceeded && result.executionCount == EXPECTED ? 0 : 1)
'''.replace('EXPECTED', str(count))
(build / 'main.swift').write_text(main)
link = ['-I', str(build), '-I', str(lib), '-L', str(build), '-L', str(lib), '-lShelfCore', '-F', str(framework)]
for path in [build, framework, lib, platform / 'Library/PrivateFrameworks']:
    link += ['-Xlinker', '-rpath', '-Xlinker', str(path)]
tests_passed = False
if '--replay-only' not in sys.argv:
    run('test-build', base + link + list(map(str, files)) + [str(build / 'main.swift'), '-o', str(build / 'intelligence-tests')])
    tests_passed = run('deterministic-tests', [str(build / 'intelligence-tests')], required=False)
pdf_files = [root / 'Shelf/Infrastructure/PDF' / name for name in [
    'PDFReadablePageExtractor.swift', 'PDFSpatialText.swift', 'PDFLineGrouper.swift',
    'PDFBlockClassifier.swift', 'PDFTextReconstructor.swift', 'PDFDocumentFurniture.swift']]
pdf_files += [root / 'Shelf/Features/Reader/ReadablePage.swift', root / 'Shelf/Learning/StudyInteractionTrace.swift']
pdf_files += [root / 'Shelf/Learning/Services' / name for name in ['PDFTextExtractor.swift', 'PDFTextExtractionCheckpointStore.swift']]
run('pdf-replay-build', base + link + ['-parse-as-library'] + list(map(str, pdf_files)) +
    [str(root / 'scripts/v28-pdf-baseline.swift'), '-o', str(build / 'v28-pdf-replay')])
run('pdf-replay', [str(build / 'v28-pdf-replay')])
if not tests_passed and '--replay-only' not in sys.argv: sys.exit(1)
