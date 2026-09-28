#!/usr/bin/env python3
"""Builds Leu's bundled semantic space: a static WordPiece vector table distilled from
sentence-transformers/all-MiniLM-L6-v2 (Apache-2.0), plus a WordNet 3.0 antonym list.

Nothing here runs in the app. The app reads the two files this script writes and compares
words by integer dot products, so every similarity is exact and identical on every device.

Distillation follows Model2Vec: each vocabulary token is encoded on its own ([CLS] t [SEP],
mean-pooled), the table is centred, reduced to 256 dimensions by PCA and quantized to int8
with one global scale (robust maximum: the 99.99th percentile of absolute values, clipped).

usage: build-semantic-space.py <minilm-onnx-dir> <wordnet-dir> <output-dir>
  <minilm-onnx-dir> holds model.onnx and vocab.txt of all-MiniLM-L6-v2 (the ONNX export used
  by Chroma: https://chroma-onnx-models.s3.amazonaws.com/all-MiniLM-L6-v2/onnx.tar.gz)
  <wordnet-dir> holds WordNet 3.0's data.{adj,adv,noun,verb} (e.g. nltk_data corpora/wordnet)
requires: numpy, onnxruntime
"""
import hashlib, os, re, struct, sys

import numpy as np

DIMS = 256
MAGIC = b"LEUSEM01"


def distil(model_dir):
    import onnxruntime as ort
    vocab = [line.rstrip("\n") for line in open(os.path.join(model_dir, "vocab.txt"), encoding="utf8")]
    options = ort.SessionOptions()
    options.intra_op_num_threads = 1
    session = ort.InferenceSession(os.path.join(model_dir, "model.onnx"), options, providers=["CPUExecutionProvider"])
    inputs = {i.name for i in session.get_inputs()}
    cls, sep = vocab.index("[CLS]"), vocab.index("[SEP]")
    table = np.zeros((len(vocab), 384), dtype=np.float64)
    for start in range(0, len(vocab), 512):
        ids = np.array([[cls, i, sep] for i in range(start, min(len(vocab), start + 512))], dtype=np.int64)
        feed = {"input_ids": ids, "attention_mask": np.ones_like(ids)}
        if "token_type_ids" in inputs:
            feed["token_type_ids"] = np.zeros_like(ids)
        table[start:start + len(ids)] = session.run(None, feed)[0].mean(axis=1)
    return vocab, table


def reduce_and_quantize(table):
    centred = table - table.mean(axis=0)
    _, _, vt = np.linalg.svd(centred, full_matrices=False)
    reduced = centred @ vt[:DIMS].T
    scale = float(np.percentile(np.abs(reduced), 99.99)) / 127.0
    return np.clip(np.round(reduced / scale), -127, 127).astype(np.int8), scale


def antonyms(wordnet_dir):
    synsets = {}
    for pos in ("adj", "adv", "noun", "verb"):
        with open(os.path.join(wordnet_dir, f"data.{pos}"), encoding="latin-1") as handle:
            for line in handle:
                if line.startswith("  "):
                    continue
                head = line.split(" | ")[0].split()
                count = int(head[3], 16)
                words = [head[4 + 2 * i].lower().split("(")[0] for i in range(count)]
                index = 4 + 2 * count
                pointers = []
                for _ in range(int(head[index])):
                    symbol, offset, target_pos, source_target = head[index + 1:index + 5]
                    index += 4
                    pointers.append((symbol, offset, "a" if target_pos in "as" else target_pos,
                                     int(source_target[:2], 16), int(source_target[2:], 16)))
                synsets[(head[0], "a" if head[2] in "as" else head[2])] = (words, pointers, head[2])
    word = re.compile(r"^[a-z]{2,20}$")
    pairs, heads = set(), {}
    for key, (words, pointers, kind) in synsets.items():
        if kind == "s":
            for symbol, offset, pos, _, _ in pointers:
                if symbol == "&":
                    heads.setdefault((offset, pos), []).extend(words)
    for key, (words, pointers, kind) in synsets.items():
        for symbol, offset, pos, source, target in pointers:
            other = synsets.get((offset, pos))
            if symbol != "!" or not other or not target:
                continue
            b = other[0][target - 1]
            sources = ([words[source - 1]] if source else []) + (heads.get(key, []) if key[1] == "a" else [])
            for a in sources:
                if word.match(a) and word.match(b) and a != b:
                    pairs.add(tuple(sorted((a, b))))
    return sorted(pairs)


def notice_header(wordnet_dir):
    """WordNet's license asks for its notice on every copy, modifications included."""
    notice = open(os.path.join(wordnet_dir, "LICENSE"), encoding="utf8").read().strip().splitlines()
    lines = ["Antonym pairs extracted from WordNet 3.0 by scripts/build-semantic-space.py."] + notice
    return "".join(f"# {line.rstrip()}\n" if line.strip() else "#\n" for line in lines)


def main(model_dir, wordnet_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    vocab, table = distil(model_dir)
    vectors, scale = reduce_and_quantize(table)
    words = "\n".join(vocab).encode("utf8")
    path = os.path.join(out_dir, "minilm-static-256.leusem")
    with open(path, "wb") as handle:
        handle.write(MAGIC)
        handle.write(struct.pack("<IIIfI", 1, DIMS, len(vocab), scale, len(words)))
        handle.write(words)
        handle.write(vectors.tobytes(order="C"))
    pairs = antonyms(wordnet_dir)
    antonym_path = os.path.join(out_dir, "wordnet-antonyms.txt")
    with open(antonym_path, "w", encoding="utf8") as handle:
        handle.write(notice_header(wordnet_dir))
        handle.write("\n".join(f"{a} {b}" for a, b in pairs) + "\n")
    for written in (path, antonym_path):
        digest = hashlib.sha256(open(written, "rb").read()).hexdigest()
        print(f"{os.path.basename(written)}: {os.path.getsize(written)} bytes sha256={digest}")
    print(f"vocabulary={len(vocab)} dims={DIMS} scale={scale:.6f} antonym pairs={len(pairs)}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
