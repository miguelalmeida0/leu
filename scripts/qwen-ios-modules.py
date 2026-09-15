#!/usr/bin/env python3
"""iOS Swift module compilation, explicitly not full app build or device execution."""
import os, pathlib, subprocess
root = pathlib.Path(__file__).resolve().parent.parent
os.chdir(root)
build = root/".qwen-local/ios-swift"
build.mkdir(parents=True,exist_ok=True)
dev = pathlib.Path("/Applications/Xcode.app/Contents/Developer")
base = [str(dev/"Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"),"-swift-version","5",
    "-target","arm64-apple-ios17.0","-sdk",str(dev/"Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"),
    "-module-cache-path",str(build/"modules"),"-I",str(build),"-F",str(root/".qwen-local/native-ios")]
for module in ["LeuReasoningCore","ShelfCore","LeuQwenRuntime"]:
    files = sorted((root/f"Packages/{module}/Sources/{module}").rglob("*.swift"))
    command = base+["-emit-module","-module-name",module,"-emit-module-path",str(build/(module+".swiftmodule"))]+list(map(str,files))
    with (root/f"docs/qwen-local/ios-{module}.txt").open("w") as log:
        result = subprocess.run(command,env=dict(os.environ,TMPDIR=str(build)),stdout=log,stderr=subprocess.STDOUT)
    if result.returncode: raise SystemExit(f"Failed {module}; inspect its iOS compilation log")
    print(module,"iOS module PASS",flush=True)
