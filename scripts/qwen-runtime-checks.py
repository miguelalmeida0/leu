#!/usr/bin/env python3
"""Build/run focused native lifecycle checks after the serial comparison."""
import os
import argparse
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
os.chdir(root)
compiler = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
host = root / ".qwen-local/host-final"
native = root / ".qwen-local/native-mac"
parser = argparse.ArgumentParser()
parser.add_argument("--long-diagnostic", action="store_true")
parser.add_argument("--build-only", action="store_true")
parser.add_argument("--output", type=Path)
options = parser.parse_args()
diagnostic = options.long_diagnostic
output = options.output.resolve() if options.output else root / ("docs/qwen-local/long-context-diagnostic.json" if diagnostic else "docs/qwen-local/runtime-lifecycle.json")
if not options.build_only:
    if output.exists():
        raise SystemExit("Preserve existing evidence; pass --output with a new filename")
    output.parent.mkdir(parents=True, exist_ok=True)
stem = "qwen-long-context-diagnostic" if diagnostic else "qwen-runtime-checks"
binary = host / stem
env = dict(os.environ, TMPDIR=str(root / ".qwen-local/tmp"))
command = [compiler, "-swift-version", "5", "-sdk",
    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk",
    "-module-cache-path", str(host / "modules"), "-I", str(host), "-L", str(host), "-F", str(native),
    "-Xlinker", "-rpath", "-Xlinker", str(host), "-Xlinker", "-rpath", "-Xlinker", str(native),
    "-parse-as-library", "-lLeuReasoningCore", "-lShelfCore", "-lLeuQwenRuntime", "-framework", "LeuQwenNative",
    "scripts/" + stem + ".swift", "-o", str(binary)]
subprocess.run(command, env=env, check=True)
if not options.build_only:
    subprocess.run([str(binary), str(root / ".qwen-local/Qwen3.5-2B-Q4_K_M.gguf"),
        str(output)], env=env, check=True, timeout=180)
