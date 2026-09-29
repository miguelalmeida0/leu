"""V37 capability spike (throwaway): blind-safe tools for the primary gate.

Every command prints only ids, counts and aggregate statistics, never learner text, credits,
claims or notes.

  merge  <out.json> <author-J.json> ... <author-O.json>      merge the six author files
  select <gate.json> <second-input.json> <map.json>          seeded pick of 10 cases per author for
                                                             the blind second label, under neutral ids
  agree  <gate.json> <labels2.json> <map.json> <summary.json> <disagreements.json>
                                                             inter-rater agreement (aggregates only)
  seal   <out-dir> <file> [<file> ...]                       encrypt with the passphrase in
                                                             LEU_GATE_PASSPHRASE, verify the round trip,
                                                             write fingerprints, delete the plaintext
"""
import collections
import hashlib
import json
import os
import random
import subprocess
import sys

SEED = 3737
STATES = ["understood", "mostlyUnderstood", "fragile", "misconception", "weakReasoning", "insufficient"]
CIPHER = ["-aes-256-cbc", "-pbkdf2", "-iter", "200000", "-salt"]


def coarse(state, misconceptions):
    """The harness's coarse label (GeneralizationEvaluation.coarse)."""
    if misconceptions or state == "misconception":
        return "misconception"
    return "positive" if state in ("understood", "mostlyUnderstood") else "weak"


def kappa(pairs):
    n = len(pairs)
    if n == 0:
        return 0.0
    observed = sum(1 for a, b in pairs if a == b) / n
    left, right = collections.Counter(a for a, _ in pairs), collections.Counter(b for _, b in pairs)
    expected = sum(left[k] * right[k] for k in set(left) | set(right)) / (n * n)
    return (observed - expected) / (1 - expected) if expected < 1 else 1.0


def canonical_bytes(path):
    return json.dumps(json.load(open(path)), sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def merge(out, paths):
    cases = []
    for path in paths:
        cases += json.load(open(path))["cases"]
    ids = collections.Counter(c["id"] for c in cases)
    assert all(n == 1 for n in ids.values()), "duplicate ids"
    json.dump({"split": "v37-primary-gate", "cases": cases}, open(out, "w"), indent=1, ensure_ascii=False)
    authors = collections.Counter(c["id"].split("-")[0] for c in cases)
    print(f"merged cases={len(cases)} authors " + " ".join(f"{a}={n}" for a, n in sorted(authors.items())))


def select(gate, second_input, mapping):
    cases = json.load(open(gate))["cases"]
    by_author = collections.defaultdict(list)
    for c in cases:
        by_author[c["id"].split("-")[0]].append(c["id"])
    rng = random.Random(SEED)
    picked = []
    for author in sorted(by_author):
        picked += rng.sample(sorted(by_author[author]), 10)
    rng.shuffle(picked)
    lookup = {c["id"]: c for c in cases}
    neutral = {f"DL-{i + 1:02d}": cid for i, cid in enumerate(picked)}
    items = [{"id": nid, "document": lookup[cid]["document"], "concept": lookup[cid].get("concept"),
              "page": lookup[cid].get("page"), "text": lookup[cid]["text"]} for nid, cid in neutral.items()]
    json.dump({"split": "v37-second-label-input", "cases": items}, open(second_input, "w"), indent=1, ensure_ascii=False)
    json.dump(neutral, open(mapping, "w"), indent=1)
    print(f"selected {len(items)} cases for blind second labelling ({len(by_author)} authors x 10), neutral ids DL-01..DL-{len(items):02d}")


def agree(gate, labels2, mapping, summary_path, disagreements_path):
    first = {c["id"]: c for c in json.load(open(gate))["cases"]}
    second = {l["id"]: l for l in json.load(open(labels2))["labels"]}
    neutral = json.load(open(mapping))
    coarse_pairs, exact_pairs, disagreements = [], [], []
    for nid, cid in sorted(neutral.items()):
        a, b = first[cid], second[nid]
        ca, cb = coarse(a["state"], a["misconceptions"]), coarse(b["state"], b["misconceptions"])
        coarse_pairs.append((ca, cb))
        exact_pairs.append((a["state"], b["state"]))
        if ca != cb:
            disagreements.append({"neutralID": nid, "caseID": cid, "first": ca, "second": cb})
    n = len(coarse_pairs)
    summary = {
        "doubleLabelled": n,
        "coarseAgreement": sum(1 for a, b in coarse_pairs if a == b) / n,
        "exactAgreement": sum(1 for a, b in exact_pairs if a == b) / n,
        "coarseKappa": kappa(coarse_pairs),
        "exactKappa": kappa(exact_pairs),
        "coarseConfusion": {f"{a}->{b}": k for (a, b), k in sorted(collections.Counter(coarse_pairs).items())},
        "coarseDisagreements": len(disagreements),
    }
    json.dump(summary, open(summary_path, "w"), indent=1, sort_keys=True)
    json.dump(disagreements, open(disagreements_path, "w"), indent=1)
    print(json.dumps(summary, indent=1, sort_keys=True))


def seal(out_dir, paths):
    passphrase = os.environ.get("LEU_GATE_PASSPHRASE")
    assert passphrase and len(passphrase) >= 32, "LEU_GATE_PASSPHRASE missing or too short"
    lines = ["# V37 primary gate: sealed files", "cipher: openssl enc " + " ".join(CIPHER) + " (passphrase held by the owner, never committed)",
             "plaintext hash: SHA-256 of canonical JSON (sorted keys, compact separators, UTF-8)", ""]
    for path in paths:
        plain = canonical_bytes(path)
        plain_hash = hashlib.sha256(plain).hexdigest()
        out = os.path.join(out_dir, os.path.basename(path) + ".enc")
        subprocess.run(["openssl", "enc", "-e", *CIPHER, "-out", out, "-pass", "env:LEU_GATE_PASSPHRASE"], input=plain, check=True)
        round_trip = subprocess.run(["openssl", "enc", "-d", *CIPHER, "-in", out, "-pass", "env:LEU_GATE_PASSPHRASE"],
                                    capture_output=True, check=True).stdout
        assert hashlib.sha256(round_trip).hexdigest() == plain_hash, f"round trip failed for {path}"
        cipher_hash = hashlib.sha256(open(out, "rb").read()).hexdigest()
        lines.append(f"{os.path.basename(out)}  plaintext-sha256={plain_hash}  ciphertext-sha256={cipher_hash}  bytes={os.path.getsize(out)}")
        os.remove(path)
        print(f"sealed {os.path.basename(path)} -> {os.path.basename(out)} (round trip verified; plaintext deleted)")
    with open(os.path.join(out_dir, "FINGERPRINTS.txt"), "a") as handle:
        handle.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    command, args = sys.argv[1], sys.argv[2:]
    if command == "merge":
        merge(args[0], args[1:])
    elif command == "select":
        select(*args)
    elif command == "agree":
        agree(*args)
    elif command == "seal":
        seal(args[0], args[1:])
    else:
        print(__doc__)
        sys.exit(2)
