#!/usr/bin/env python3
"""Build the pinned native runtime locally. Never downloads model weights."""
import argparse, hashlib, os, pathlib, shutil, subprocess, tarfile, urllib.request
ROOT = pathlib.Path(__file__).resolve().parent.parent
PIN = "4c9233c034fc450dcf34c7c0988aebe6da5cdf1a"
ARCHIVE_HASH = "bb545c88df2d7e20732863cc676118e609a9d3ac5448f65134a2e6ac75e5df7d"
LOCAL = ROOT / ".qwen-local"
DEV = pathlib.Path("/Applications/Xcode.app/Contents/Developer")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=["mac", "all"], default="all")
    args = parser.parse_args()
    LOCAL.mkdir(exist_ok=True)
    (LOCAL / "tmp").mkdir(exist_ok=True)
    env = dict(os.environ, TMPDIR=str(LOCAL / "tmp"), GIT_CEILING_DIRECTORIES=str(LOCAL))
    cmake = shutil.which("cmake") or str(LOCAL / "build-tools/cmake/data/bin/cmake")
    if not pathlib.Path(cmake).is_file():
        raise SystemExit("Install cmake 4.1.0, or: TMPDIR=" + str(LOCAL / "tmp") + " python3 -m pip install --target " + str(LOCAL / "build-tools") + " cmake==4.1.0")
    archive = LOCAL / "llama.tar.gz"
    if not archive.exists():
        urllib.request.urlretrieve(f"https://github.com/ggml-org/llama.cpp/archive/{PIN}.tar.gz", archive)
    assert hashlib.file_digest(archive.open("rb"), "sha256").hexdigest() == ARCHIVE_HASH, "Runtime archive mismatch"
    source = LOCAL / ("llama.cpp-" + PIN)
    if not source.exists():
        with tarfile.open(archive) as tar: tar.extractall(LOCAL, filter="data")
    configurations = [("mac", "MacOSX", "MacOSX", None)]
    if args.platform == "all":
        configurations += [("ios", "iPhoneOS", "iPhoneOS", "iOS"), ("simulator", "iPhoneSimulator", "iPhoneSimulator", "iOS")]
    frameworks = []
    for name, platform, sdk, system in configurations:
        build = LOCAL / ("native-" + name)
        command = [cmake, "-S", str(ROOT / "Native/Qwen"), "-B", str(build), "-DLLAMA_SOURCE=" + str(source),
                   "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_OSX_ARCHITECTURES=arm64", "-DGGML_NATIVE=OFF",
                   "-DCMAKE_C_COMPILER=" + str(DEV / "Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"),
                   "-DCMAKE_CXX_COMPILER=" + str(DEV / "Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++"),
                   "-DCMAKE_OSX_SYSROOT=" + str(DEV / f"Platforms/{platform}.platform/Developer/SDKs/{sdk}.sdk")]
        if system:
            command += ["-DCMAKE_SYSTEM_NAME=" + system, "-DCMAKE_OSX_DEPLOYMENT_TARGET=17.0", "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY", "-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO"]
        subprocess.run(command, env=env, check=True)
        subprocess.run([cmake, "--build", str(build), "--target", "LeuQwenNative", "-j", "4"], env=env, check=True)
        framework = build / "LeuQwenNative.framework"
        modules = framework / ("Versions/A/Modules" if name == "mac" else "Modules")
        modules.mkdir(exist_ok=True, parents=True)
        (modules / "module.modulemap").write_text('framework module LeuQwenNative {\n  umbrella header "LeuQwenNative.h"\n  export *\n}\n')
        if name == "mac" and not (framework / "Modules").exists():
            (framework / "Modules").symlink_to("Versions/Current/Modules")
        notices = []
        for license_file in sorted(source.rglob("*")):
            if license_file.is_file() and license_file.name.upper().startswith(("LICENSE", "COPYING", "NOTICE")):
                notices.append(str(license_file.relative_to(source)) + "\n" + license_file.read_text(errors="replace"))
        notices.append("Qwen model license\n" + (ROOT/"docs/qwen-local/licenses/Qwen-Apache-2.0.txt").read_text())
        resources = framework / ("Versions/A/Resources" if name == "mac" else "Resources")
        resources.mkdir(exist_ok=True, parents=True)
        (resources/"ThirdPartyNotices.txt").write_text("\n\n".join(notices))
        frameworks += ["-framework", str(framework)]
    output = ROOT / "Packages/LeuQwenRuntime/Artifacts/LeuQwenNative.xcframework"
    output.parent.mkdir(parents=True, exist_ok=True)
    staging = output.with_name("LeuQwenNative.pending.xcframework")
    if staging.exists(): shutil.rmtree(staging)  # Only generated staging owned by this script.
    subprocess.run([str(DEV / "usr/bin/xcodebuild"), "-create-xcframework", *frameworks, "-output", str(staging)], env=env, check=True)
    if output.exists(): shutil.rmtree(output)  # Replaces this generated runtime, never source or weights.
    staging.rename(output)
    print("Prepared", output)

if __name__ == "__main__": main()
