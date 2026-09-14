"""Runner control-flow regression only: stub commands never launch or certify iOS."""
from pathlib import Path
import json, os, shutil, subprocess, tempfile
ROOT = Path(__file__).resolve().parents[4]
SCRIPT = ROOT / "scripts/verify-study-home.sh"
STUB = r'''import json,sys,os
from pathlib import Path
tool=Path(sys.argv[0]).name; args=sys.argv[1:]
with open(os.environ["RUNNER_CALLS"],"a") as f: f.write(json.dumps([tool,*args])+"\n")
if tool=="xcodebuild":
    assert "test-without-building" in args, args
    assert not any(x in args for x in ["build","test"]), args
    assert [x for x in args if x.startswith("-only-testing:")]==["-only-testing:ShelfUITests/ShelfStudyHomeUITests"], args
    Path(args[args.index("-resultBundlePath")+1]).mkdir()
elif args[:2]==["simctl","ui"] and len(args)==4:
    print("large")
elif args[:4]==["xcresulttool","get","test-results","summary"]:
    print(json.dumps(dict(result="Passed",passedTests=2,failedTests=0,skippedTests=0)))
elif args[:3]==["xcresulttool","export","attachments"]:
    out=Path(args[args.index("--output-path")+1]);out.mkdir(exist_ok=True)
    (out/"manifest.json").write_text("[]")
'''
with tempfile.TemporaryDirectory(prefix="runner-check-", dir=ROOT/".build") as temp:
    root=Path(temp); (root/"scripts").mkdir(); (root/"bin").mkdir()
    shutil.copyfile(SCRIPT,root/"scripts/verify-study-home.sh")
    for tool in ["xcrun","xcodebuild"]:
        path=root/"bin"/tool
        import sys
        path.write_text("#!"+sys.executable+"\n"+STUB);path.chmod(0o755)
    products=root/".build/study-home/Build/Products/Debug-iphonesimulator"
    for product in ["Shelf.app","ShelfUITests-Runner.app"]: (products/product).mkdir(parents=True)
    run=root/"saved";run.mkdir();(run/"default.xcresult").mkdir()
    default=dict(result="Failed",passedTests=4,failedTests=1,skippedTests=0)
    (run/"default-summary.json").write_text(json.dumps(default))
    (run/"default-attachments").mkdir();(run/"default-attachments/manifest.json").write_text("[]")
    calls=root/"calls.jsonl"
    env=dict(os.environ, PATH=str(root/"bin")+":"+os.environ["PATH"],RUNNER_CALLS=str(calls))
    def invoke():
        calls.write_text("")
        result=subprocess.run(["/bin/bash",str(root/"scripts/verify-study-home.sh"),"--resume",str(run)],
                              env=env,capture_output=True,text=True)
        assert result.returncode==65,(result.returncode,result.stdout,result.stderr)
        assert "unbound variable" not in result.stderr
        return [json.loads(line) for line in calls.read_text().splitlines()]
    first=invoke()
    native=[c for c in first if c[0]=="xcodebuild"]
    assert len(native)==1,first
    assert json.loads((run/"default-summary.json").read_text())==default
    print("PASS: Bash 3.2 resumes AX1 only, no rebuild/default retest, retained failure exit 65.")
    second=invoke()
    assert second==[],second
    print("PASS: complete saved evidence needs no Xcode or simulator calls.")
    (run/"AX1-summary.json").unlink()
    (run/"AX1-attachments/manifest.json").unlink()
    third=invoke()
    assert len(third)==2 and all(c[1]=="xcresulttool" for c in third),third
    print("PASS: missing summary/attachments require export only, no native rerun.")

