#!/usr/bin/env python3
"""Replay focused existing production checks, preserving historical reports."""
import hashlib, json, os, pathlib, subprocess, sys
root = pathlib.Path(__file__).resolve().parent.parent
os.chdir(root)
build = root / ".qwen-local/host-v2"
out = root / "docs/qwen-local/regressions"
out.mkdir(exist_ok=True, parents=True)
source = root.parent / "LeuV29Integration/docs/v28/evidence/baseline"
target = root / "docs/v28/evidence/baseline"
target.mkdir(exist_ok=True, parents=True)
hashes = {}
for name in ["javascript_midlevel_interview_mobile_mastery", "React Notes", "JavaScript Deep Dive", "System Design"]:
    path = source / (name + "-analysis.json")
    data = path.read_bytes()
    dest = target / path.name
    if dest.exists(): assert dest.read_bytes() == data
    else: dest.write_bytes(data)
    assert path.read_bytes() == data, "Input snapshot changed while reading"
    hashes[str(path)] = hashlib.sha256(data).hexdigest()
(out / "input-snapshot-hashes.json").write_text(json.dumps(hashes, indent=2)+"\n")
dev = pathlib.Path("/Applications/Xcode.app/Contents/Developer")
base = [str(dev/"Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"), "-swift-version", "5", "-parse-as-library",
    "-sdk", str(dev/"Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"), "-module-cache-path", str(build/"modules"),
    "-I",str(build),"-L",str(build),"-lShelfCore","-lLeuReasoningCore","-Xlinker","-rpath","-Xlinker",str(build)]
env = dict(os.environ,TMPDIR=str(build))
checks = [("teach", "v291-teach-integration.swift", "evidence/v29.1/after"),
          ("cache", "v28-instant-tests.swift", "docs/v28.1/performance"),
          ("product", "v28-product-integration.swift", "docs/v28/productization")]
for name, file, old in checks:
    if name == "teach" and "--skip-teach" in sys.argv: continue
    text = (root/"scripts"/file).read_text().replace('appendingPathComponent("'+old+'")', 'appendingPathComponent("docs/qwen-local/regressions")')
    text = text.replace('out.appendingPathComponent("baseline-questions.json")', 'root.appendingPathComponent("docs/v28.1/performance/baseline-questions.json")')
    fixture = build / ("qwen-regression-" + file)
    fixture.write_text(text)
    extra = ["Shelf/Learning/Intelligence/TeachReasoningAdapter.swift"] if name == "teach" else []
    binary = build / ("regression-"+name)
    with (out/(name+"-build.txt")).open("w") as log:
        subprocess.run(base+extra+[str(fixture),"-o",str(binary)],env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
    with (out/(name+"-run.txt")).open("w") as log:
        subprocess.run([str(binary)],env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
    print(name,"PASS",flush=True)
