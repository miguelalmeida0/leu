#!/usr/bin/env python3
"""Compile current Swift modules with the iOS SDK and cached ONNX headers.

This does not link/package the app, execute XCTest, or certify native behavior.
It is useful when Xcode's package lock/CoreSimulator is unavailable.
"""
from pathlib import Path
import os
import subprocess

root = Path(__file__).resolve().parent.parent
dev = Path('/Applications/Xcode.app/Contents/Developer')
build = root / '.build/v27-ios'
proof = root / 'docs/v27/evidence'
build.mkdir(parents=True, exist_ok=True)
platform = dev / 'Platforms/iPhoneSimulator.platform/Developer'
cache = root.parent / 'LeuNightFieldContrast/.build/study-home'
modulemap = cache / 'Build/Intermediates.noindex/GeneratedModuleMaps-iphonesimulator/OnnxRuntimeBindings.modulemap'
assert modulemap.is_file(), 'Existing ONNX module map is required; do not silently omit this branch'
base = [str(dev / 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'),
        '-swift-version', '5', '-sdk', str(platform / 'SDKs/iPhoneSimulator.sdk'),
        '-target', 'arm64-apple-ios17.0-simulator', '-module-cache-path', str(build / 'modules'),
        '-DDEBUG', '-strict-concurrency=targeted', '-enable-testing', '-I', str(build)]
onnx = ['-Xcc', '-fmodule-map-file=' + str(modulemap)]
onnx += ['-Xcc', '-I' + str(cache / 'SourcePackages/checkouts/onnxruntime-swift-package-manager/objectivec/include')]
for module, files, extra in [
    ('ShelfCore', sorted((root / 'Packages/ShelfCore/Sources/ShelfCore').rglob('*.swift')), []),
    ('VoiceBugfix', sorted((root / 'Shelf/Voice/Engine').glob('*.swift')) +
     [root / 'Shelf/Learning/StudyInteractionTrace.swift'], onnx),
    ('Shelf', sorted((root / 'Shelf').rglob('*.swift')), onnx),
]:
    command = base + extra + ['-emit-module', '-module-name', module,
        '-emit-module-path', str(build / (module + '.swiftmodule'))] + list(map(str, files))
    with (proof / ('ios-module-' + module + '.log')).open('w') as log:
        result = subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT,
                                env=dict(os.environ, TMPDIR=str(build)))
    print(module, 'PASS' if result.returncode == 0 else 'FAIL', flush=True)
    if result.returncode:
        raise SystemExit(result.returncode)
print('iOS Swift module compile PASS. Xcode build and native execution still required.')
