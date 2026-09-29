"""V37 NH holdout (throwaway): seals the NH plaintext files (HOLDOUT_PLAN "Sealing").

For each file: the plaintext SHA-256 of its canonical JSON (sorted keys, compact separators, UTF-8), then
`openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -pass file:<passphrase-file>` (the passphrase is never
on a command line, never read or printed by this script), then the ciphertext SHA-256. Writes the .enc
files and FINGERPRINTS.txt into <out-dir>; prints hashes and sizes only.

usage: python3 nh_seal.py <work-dir> <out-dir> <passphrase-file>
"""
import hashlib
import json
import os
import subprocess
import sys

FILES = [("nh.json", "nh-holdout.json"), ("labels2.json", "nh-labels2.json"), ("double-label-map.json", "nh-double-label-map.json")]


def main(work, out, passphrase):
    mode = os.stat(passphrase).st_mode & 0o777
    assert mode == 0o600, "the passphrase file must be 0600"
    os.makedirs(out, exist_ok=True)
    lines = ["# V37 NH holdout: sealed files",
             "cipher: openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt (passphrase file held by the owner, never committed)",
             "plaintext hash: SHA-256 of canonical JSON (sorted keys, compact separators, UTF-8)", ""]
    for source, name in FILES:
        data = json.load(open(os.path.join(work, source)))
        canonical = json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        plain_sha = hashlib.sha256(canonical).hexdigest()
        plain_path = os.path.join(work, name)
        with open(plain_path, "wb") as handle:
            handle.write(canonical)
        target = os.path.join(out, name + ".enc")
        subprocess.run(["openssl", "enc", "-aes-256-cbc", "-pbkdf2", "-iter", "200000", "-salt", "-in", plain_path,
                        "-out", target, "-pass", f"file:{passphrase}"], check=True)
        # The seal must open again with the same passphrase file and give the same bytes (checked in memory).
        opened = subprocess.run(["openssl", "enc", "-d", "-aes-256-cbc", "-pbkdf2", "-iter", "200000", "-in", target,
                                 "-pass", f"file:{passphrase}"], check=True, capture_output=True).stdout
        assert hashlib.sha256(opened).hexdigest() == plain_sha, "round trip failed"
        cipher_sha = hashlib.sha256(open(target, "rb").read()).hexdigest()
        lines.append(f"{name}.enc  plaintext-sha256={plain_sha}  ciphertext-sha256={cipher_sha}  bytes={os.path.getsize(target)}")
        print(lines[-1])
    with open(os.path.join(out, "FINGERPRINTS.txt"), "w") as handle:
        handle.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main(*sys.argv[1:4])
