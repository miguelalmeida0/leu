#!/usr/bin/env python3
"""Compile the actual package and XCTest sources without invoking SwiftPM's manifest sandbox."""
from pathlib import Path
import os, subprocess, shutil, plistlib, sys
root = Path(__file__).resolve().parent.parent
os.chdir(root)
build = root/'.build/v29-host'
out = root/'evidence/v29-real-reasoning'
build.mkdir(parents=True, exist_ok=True); out.mkdir(parents=True, exist_ok=True)
dev = Path('/Applications/Xcode.app/Contents/Developer')
platform = dev/'Platforms/MacOSX.platform/Developer'
swift = dev/'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'
env = dict(os.environ, TMPDIR=str(build), LEU_EVAL_REPORT=str(out/'golden-evaluation.json'))
base = [str(swift), '-swift-version','5','-sdk',str(platform/'SDKs/MacOSX.sdk'), '-module-cache-path',str(build/'modules')]
def run(name, args):
    with (out/(name+'.log')).open('w') as log:
        result = subprocess.run(args, env=env, stdout=log, stderr=subprocess.STDOUT)
    print(name, 'PASS' if result.returncode==0 else 'FAIL', flush=True)
    if result.returncode:
        print((out/(name+'.log')).read_text()[-8000:]); sys.exit(result.returncode)
sources = sorted((root/'Packages/LeuReasoningCore/Sources/LeuReasoningCore').rglob('*.swift'))
run('host-build', base+['-emit-library','-emit-module','-enable-testing','-module-name','LeuReasoningCore','-emit-module-path',str(build/'LeuReasoningCore.swiftmodule'),'-o',str(build/'libLeuReasoningCore.dylib')]+list(map(str,sources)))
bundle = build/'ReasoningTests.xctest'
(bundle/'Contents/MacOS').mkdir(parents=True,exist_ok=True)
(bundle/'Contents/Resources').mkdir(parents=True,exist_ok=True)
shutil.copytree(root/'Packages/LeuReasoningCore/Tests/LeuReasoningCoreTests/Fixtures',bundle/'Contents/Resources/Fixtures',dirs_exist_ok=True)
(bundle/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'dev.leu.reasoning.host-tests','CFBundleExecutable':'ReasoningTests','CFBundlePackageType':'BNDL'}))
accessor = build/'resource_bundle_accessor.swift'
accessor.write_text('import Foundation\nextension Bundle { static let module = Bundle(path: '+repr(str(bundle)).replace("'",'"')+')! }\n')
tests = sorted((root/'Packages/LeuReasoningCore/Tests/LeuReasoningCoreTests').glob('*.swift'))
run('host-tests-build', base+['-emit-library','-module-name','LeuReasoningCoreTests','-I',str(build),'-L',str(build),'-lLeuReasoningCore','-F',str(platform/'Library/Frameworks'),'-framework','XCTest','-I',str(platform/'usr/lib'),'-L',str(platform/'usr/lib'),'-Xlinker','-rpath','-Xlinker',str(build),'-o',str(bundle/'Contents/MacOS/ReasoningTests')]+list(map(str,tests))+[str(accessor)])
run('host-tests',[str(dev/'usr/bin/xctest'),str(bundle)])
print((out/'host-tests.log').read_text()[-600:])
