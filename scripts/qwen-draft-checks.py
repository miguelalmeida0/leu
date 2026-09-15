#!/usr/bin/env python3
"""Compile changed persistence separately; never replace frozen benchmark libs."""
import os
import argparse
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
os.chdir(root)
parser = argparse.ArgumentParser()
parser.add_argument("--source-excerpts", action="store_true")
parser.add_argument("--output", type=Path)
options = parser.parse_args()
if options.output:
    options.output = options.output.resolve()
    if options.output.exists():
        raise SystemExit("Preserve existing evidence; choose a new --output filename")
    options.output.parent.mkdir(parents=True, exist_ok=True)
build = root / ".qwen-local/draft-build"
build.mkdir(parents=True, exist_ok=True)
compiler = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
base = [compiler, "-swift-version", "5", "-sdk",
    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk",
    "-module-cache-path", str(build / "modules"), "-I", str(build), "-L", str(build),
    "-Xlinker", "-rpath", "-Xlinker", str(build)]
env = dict(os.environ, TMPDIR=str(build))
sources = sorted((root / "Packages/ShelfCore/Sources/ShelfCore").rglob("*.swift"))
subprocess.run(base + ["-emit-library", "-emit-module", "-module-name", "ShelfCore",
    "-emit-module-path", str(build / "ShelfCore.swiftmodule"), "-o", str(build / "libShelfCore.dylib")]
    + list(map(str, sources)), env=env, check=True)
stem = "qwen-source-excerpt-checks" if options.source_excerpts else "qwen-draft-checks"
binary = build / stem
subprocess.run(base + ["-parse-as-library", "-lShelfCore", "scripts/" + stem + ".swift", "-o", str(binary)], env=env, check=True)
subprocess.run([str(binary)] + ([str(options.output)] if options.output else []), env=env, check=True)
