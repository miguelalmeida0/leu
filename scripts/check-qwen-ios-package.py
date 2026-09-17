#!/usr/bin/env python3
"""Read-only pre-install gate for the final signed iPhone app payload."""
import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess

p = argparse.ArgumentParser()
p.add_argument("app", type=Path)
p.add_argument("--output", required=True, type=Path)
a = p.parse_args()
if a.output.exists():
    p.error("Preserve previous evidence; choose another output")
dev = Path("/Applications/Xcode.app/Contents/Developer")
otool = str(dev / "Toolchains/XcodeDefault.xctoolchain/usr/bin/otool")
records = []
checks = {}

def run(command):
    result = subprocess.run(command, capture_output=True, text=True)
    text = result.stdout + result.stderr
    records.append(dict(command=command, exit=result.returncode, output=text))
    return result.returncode, text

frameworks = a.app / "Frameworks"
checks["app_exists"] = a.app.is_dir()
app_code, app_signature = run(["codesign", "-dvvv", str(a.app)])
app_team = re.search(r"^TeamIdentifier=(.+)$", app_signature, re.MULTILINE)
checks["app_has_signing_team"] = app_code == 0 and app_team is not None and app_team[1] != "not set"
entries = sorted(frameworks.iterdir()) if frameworks.is_dir() else []
checks["qwen_embedded_once"] = sum(x.name == "LeuQwenNative.framework" for x in entries) == 1
for framework in entries:
    prefix = framework.name + ": "
    checks[prefix + "framework_bundle"] = framework.is_dir() and framework.suffix == ".framework"
    if not checks[prefix + "framework_bundle"]:
        continue
    code, _ = run(["plutil", "-lint", str(framework / "Info.plist")])
    checks[prefix + "plist_lint"] = code == 0
    try:
        info = plistlib.loads((framework / "Info.plist").read_bytes())
    except Exception:
        info = {}
    keys = ("CFBundleExecutable", "CFBundleIdentifier", "CFBundleName", "CFBundleVersion",
            "CFBundleShortVersionString")
    if framework.stem == "LeuQwenNative":
        keys += ("CFBundleInfoDictionaryVersion",)
    checks[prefix + "framework_metadata"] = info.get("CFBundlePackageType") == "FMWK" and all(info.get(k) for k in keys)
    executable = info.get("CFBundleExecutable", "")
    checks[prefix + "executable_name"] = executable == framework.stem
    binary = framework / framework.stem
    code, text = run(["file", str(binary)])
    checks[prefix + "arm64_dynamic_binary"] = code == 0 and "dynamically linked shared library arm64" in text
    code, text = run([otool, "-hv", str(binary)])
    checks[prefix + "mach_o_dylib"] = code == 0 and "DYLIB" in text
    code, text = run([otool, "-l", str(binary)])
    checks[prefix + "iphoneos_platform"] = code == 0 and bool(re.search(r"platform\s+(2|IOS)\s", text)) and not re.search(r"platform\s+(7|IOSSIMULATOR)\s", text)
    run([otool, "-L", str(binary)])
    code, text = run(["codesign", "-dvvv", str(framework)])
    checks[prefix + "signed_bound_plist"] = code == 0 and "Info.plist entries=" in text and "Signature=adhoc" not in text and "TeamIdentifier=not set" not in text
    team = re.search(r"^TeamIdentifier=(.+)$", text, re.MULTILINE)
    checks[prefix + "same_signing_team_as_app"] = bool(app_team and team and app_team[1] == team[1] and team[1] != "not set")
    checks[prefix + "no_nested_framework"] = not any(framework.rglob("*.framework"))
    if framework.stem == "LeuQwenNative":
        checks[prefix + "shallow_layout"] = not (framework / "Resources").exists() and not (framework / "Versions").exists()
        checks[prefix + "notices_present"] = (framework / "ThirdPartyNotices.txt").is_file()
        checks[prefix + "no_app_icon_key"] = "CFBundleIconFile" not in info
code, _ = run(["codesign", "--verify", "--deep", "--strict", str(a.app)])
checks["app_codesign_deep_strict"] = code == 0
report = dict(app=str(a.app.resolve()), checks=checks, commands=records, passed=all(checks.values()),
              scope="Final app pre-install validation; does not establish physical installation or launch")
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(checks, indent=2))
raise SystemExit(0 if report["passed"] else 1)
