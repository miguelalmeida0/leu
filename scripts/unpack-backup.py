#!/usr/bin/env python3
"""Extract owned PDF originals from a Shelf backup without requiring Shelf or Apple tools."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import sys
import tempfile
import uuid

MAGIC = b"SHELF-BACKUP\n1\n"
MAX_MANIFEST = 32 * 1024 * 1024
MAX_DOCUMENT = 1024 * 1024 * 1024
CHUNK = 1024 * 1024


def exact(stream, length: int) -> bytes:
    result = bytearray()
    while len(result) < length:
        chunk = stream.read(length - len(result))
        if not chunk:
            raise ValueError("The backup is truncated.")
        result.extend(chunk)
    return bytes(result)


def validate_entries(manifest: dict) -> list[dict]:
    if manifest.get("version") != 1:
        raise ValueError("Unsupported backup version.")
    entries = manifest.get("originals")
    library = manifest.get("library", {})
    if not isinstance(entries, list) or not isinstance(library, dict):
        raise ValueError("Invalid document list or library.")
    if library.get("schemaVersion") != 1:
        raise ValueError("Unsupported library schema.")
    books = library.get("books", [])
    if not isinstance(books, list) or len(entries) > 100_000:
        raise ValueError("Invalid or excessive document count.")
    known = {}
    for book in books:
        key = str(uuid.UUID(book["id"]))
        if key in known:
            raise ValueError("Duplicate book identity.")
        known[key] = book
    seen = set()
    for entry in entries:
        key = str(uuid.UUID(entry["id"]))
        size, digest = entry["size"], entry["fingerprint"]
        if key in seen or key not in known:
            raise ValueError("Duplicate or unrecognized original.")
        if type(size) is not int or not 0 < size <= MAX_DOCUMENT:
            raise ValueError("Invalid document size.")
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("Invalid checksum.")
        book = known[key]
        if book.get("byteCount") != size or book.get("fingerprint") != digest:
            raise ValueError("The manifest and original list disagree.")
        seen.add(key)
    if seen != set(known):
        raise ValueError("An original PDF is missing from the archive list.")
    return entries


def extract(source: Path, destination: Path) -> int:
    if destination.exists():
        raise ValueError("The destination already exists. Choose a new directory; nothing is overwritten.")
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".shelf-extract-", dir=destination.parent))
    committed = False
    try:
        with source.open("rb") as stream:
            if exact(stream, len(MAGIC)) != MAGIC:
                raise ValueError("This is not a Shelf v1 backup.")
            length = struct.unpack("<Q", exact(stream, 8))[0]
            if not 0 < length <= MAX_MANIFEST:
                raise ValueError("Manifest exceeds safety limits.")
            manifest = json.loads(exact(stream, length))
            if not isinstance(manifest, dict):
                raise ValueError("The manifest must be a JSON object.")
            entries = validate_entries(manifest)
            originals = staging / "Originals"
            originals.mkdir()
            for entry in entries:
                name = str(uuid.UUID(entry["id"])).upper() + ".pdf"
                digest = hashlib.sha256()
                remaining = entry["size"]
                with (originals / name).open("xb") as output:
                    while remaining:
                        chunk = exact(stream, min(CHUNK, remaining))
                        digest.update(chunk)
                        output.write(chunk)
                        remaining -= len(chunk)
                    output.flush()
                    os.fsync(output.fileno())
                if digest.hexdigest() != entry["fingerprint"]:
                    raise ValueError("A PDF checksum failed. No recovered directory was committed.")
            if stream.read(1):
                raise ValueError("Unexpected trailing data in archive.")
            (staging / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
        if destination.exists():
            raise ValueError("The output directory appeared during extraction; refusing to overwrite it.")
        staging.rename(destination)
        committed = True
        return len(entries)
    finally:
        if not committed:
            shutil.rmtree(staging, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("backup", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    try:
        count = extract(args.backup, args.destination)
        print(f"Recovered {count} original PDF(s) and manifest.json to {args.destination}")
        print("Sidecar notes remain in the manifest; original PDF bytes are unchanged.")
        return 0
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        print(f"Shelf recovery failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
