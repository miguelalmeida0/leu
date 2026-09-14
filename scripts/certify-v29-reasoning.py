#!/usr/bin/env python3
"""Build the pure reasoning package and execute the real-PDF certification."""
from pathlib import Path
import os, subprocess
root = Path(__file__).resolve().parent.parent
os.chdir(root)
build = root/'.build/v29-host'
build.mkdir(parents=True,exist_ok=True)
dev = Path('/Applications/Xcode.app/Contents/Developer')
env = dict(os.environ,TMPDIR=str(build))
base = [str(dev/'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'),'-swift-version','5','-sdk',str(dev/'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'),'-module-cache-path',str(build/'modules')]
sources = sorted((root/'Packages/LeuReasoningCore/Sources/LeuReasoningCore').rglob('*.swift'))
subprocess.run(base+['scripts/v29-pdf-bridge.swift','-o',str(build/'pdf-bridge')],env=env,check=True)
subprocess.run([str(build/'pdf-bridge')],env=env,check=True)
subprocess.run(base+['-emit-library','-emit-module','-enable-testing','-module-name','LeuReasoningCore','-emit-module-path',str(build/'LeuReasoningCore.swiftmodule'),'-o',str(build/'libLeuReasoningCore.dylib')]+list(map(str,sources)),env=env,check=True)
subprocess.run(base+['-I',str(build),'-L',str(build),'-lLeuReasoningCore','-Xlinker','-rpath','-Xlinker',str(build),'scripts/v29-certify.swift','-o',str(build/'certify')],env=env,check=True)
subprocess.run([str(build/'certify')],env=env,check=True)
