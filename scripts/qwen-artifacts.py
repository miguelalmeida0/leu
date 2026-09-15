#!/usr/bin/env python3
"""Explicit pinned model download and byte-level metadata inventory. No inference."""
import argparse, hashlib, json, pathlib, struct, time, urllib.request
ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "docs/qwen-local/MODEL_MANIFEST.json"

def metadata(path):
    with path.open("rb") as f:
        def unpack(fmt): return struct.unpack("<" + fmt, f.read(struct.calcsize("<" + fmt)))[0]
        def string(): return f.read(unpack("Q")).decode("utf-8", errors="strict")
        def value(kind):
            if kind == 8: return string()
            if kind == 9:
                subtype, count = unpack("I"), unpack("Q")
                return [value(subtype) for _ in range(count)]
            return unpack({0:"B",1:"b",2:"H",3:"h",4:"I",5:"i",6:"f",7:"?",10:"Q",11:"q",12:"d"}[kind])
        assert f.read(4) == b"GGUF"
        version, tensors, count = unpack("I"), unpack("Q"), unpack("Q")
        data, hashes = {}, {}
        for _ in range(count):
            key, kind = string(), unpack("I")
            start = f.tell(); data[key] = value(kind); end = f.tell()
            if key.startswith("tokenizer."):
                f.seek(start); hashes[key] = hashlib.sha256(f.read(end-start)).hexdigest()
                f.seek(end)
        selected = {k:v for k,v in data.items() if not isinstance(v,list)}
        template = selected.pop("tokenizer.chat_template", "")
        return {"gguf_version":version,"tensor_count":tensors,"metadata":selected,
            "tokenizer_field_sha256":hashes,"chat_template":template,
            "end_token_spellings": {k:data.get("tokenizer.ggml.tokens",[])[v] for k,v in data.items()
                if k.startswith("tokenizer.") and k.endswith("token_id") and isinstance(v,int) and 0 <= v < len(data.get("tokenizer.ggml.tokens",[]))}}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("size", choices=["0.8B","2B","4B"])
    parser.add_argument("--download", action="store_true", help="Explicitly download this one candidate")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    artifact = next(x for x in manifest["candidates"] if x["upstream"].endswith("-"+args.size))
    target = ROOT / ".qwen-local" / artifact["filename"]
    downloaded = not target.exists()
    start = time.monotonic()
    if not target.exists():
        if not args.download: raise SystemExit("Not installed. Add --download to fetch exactly " + str(artifact["bytes"]) + " bytes")
        staging = target.with_suffix(".gguf.partial")
        if staging.exists(): raise SystemExit("Partial download exists; inspect it before retrying")
        print("Downloading", artifact["bytes"], "bytes", flush=True)
        url = f'https://huggingface.co/{artifact["quantization_repository"]}/resolve/{artifact["quantization_revision"]}/{artifact["filename"]}'
        with urllib.request.urlopen(url, timeout=60) as response, staging.open("xb") as output:
            while chunk := response.read(4*1024*1024):
                output.write(chunk)
                if output.tell() > artifact["bytes"]: raise ValueError("Oversized download")
        assert staging.stat().st_size == artifact["bytes"]
        assert hashlib.file_digest(staging.open("rb"),"sha256").hexdigest() == artifact["sha256"]
        staging.rename(target)
    assert target.stat().st_size == artifact["bytes"]
    assert hashlib.file_digest(target.open("rb"),"sha256").hexdigest() == artifact["sha256"]
    report = metadata(target)
    template = report.pop("chat_template")
    (ROOT/f"docs/qwen-local/template-{args.size}.jinja").write_text(template)
    report["chat_template_utf8_sha256"] = hashlib.sha256(template.encode()).hexdigest()
    report["operation_seconds"] = time.monotonic()-start
    report["operation_scope"] = "download, checksum and metadata inspection" if downloaded else "existing-file checksum and metadata inspection only"
    (ROOT/f"docs/qwen-local/metadata-{args.size}.json").write_text(json.dumps(report,indent=2)+"\n")
    artifact["downloaded_and_hash_verified"] = True
    artifact["metadata_file"] = f"metadata-{args.size}.json"
    artifact["tokenizer_chat_template_sha256"] = report["chat_template_utf8_sha256"]
    MANIFEST.write_text(json.dumps(manifest,indent=2)+"\n")
    print("Verified", args.size, flush=True)

if __name__ == "__main__": main()
