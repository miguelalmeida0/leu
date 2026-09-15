#!/usr/bin/env python3
"""Compile the production modules and local fixture runner with the host SDK."""
from pathlib import Path
import os, subprocess
root = Path(__file__).resolve().parent.parent
os.chdir(root)
build = root / ".qwen-local" / os.environ.get("LEU_QWEN_BUILD_NAME", "host")
build.mkdir(parents=True, exist_ok=True)
out = root / "docs/qwen-local"
dev = Path("/Applications/Xcode.app/Contents/Developer")
frameworks = root / ".qwen-local/native-mac"
env = dict(os.environ, TMPDIR=str(build))
base = [str(dev / "Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"), "-swift-version", "5",
        "-sdk", str(dev / "Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"),
        "-module-cache-path", str(build / "modules"), "-I", str(build), "-L", str(build),
        "-F", str(frameworks), "-Xlinker", "-rpath", "-Xlinker", str(build),
        "-Xlinker", "-rpath", "-Xlinker", str(frameworks)]
for module in ["LeuReasoningCore", "ShelfCore", "LeuQwenRuntime"]:
    sources = sorted((root / f"Packages/{module}/Sources/{module}").rglob("*.swift"))
    links = ["-lLeuReasoningCore", "-framework", "LeuQwenNative"] if module == "LeuQwenRuntime" else []
    command = base + ["-emit-library", "-emit-module", "-enable-testing", "-module-name", module,
        "-emit-module-path", str(build / f"{module}.swiftmodule"), "-o", str(build / f"lib{module}.dylib")] + list(map(str, sources)) + links
    with (out / f"host-{module}.txt").open("w") as log:
        result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode: raise SystemExit((out / f"host-{module}.txt").read_text()[-12000:])
    print("Compiled", module, flush=True)
command = base + ["-parse-as-library", "-lLeuReasoningCore", "-lShelfCore", "-lLeuQwenRuntime", "-framework", "LeuQwenNative",
    "Shelf/Learning/Intelligence/TeachReasoningAdapter.swift", "scripts/qwen-benchmark.swift", "-o", str(build / "qwen-benchmark")]
with (out / "host-benchmark-build.txt").open("w") as log:
    result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT)
if result.returncode: raise SystemExit((out / "host-benchmark-build.txt").read_text()[-12000:])
print("Built", build / "qwen-benchmark")
