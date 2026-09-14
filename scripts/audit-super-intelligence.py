#!/usr/bin/env python3
"""Toolchain-free audit of the LeuReasoningCore package and its golden corpus.

This does NOT replace the Swift certification suite: it cannot execute the
engine. What it does check, on any machine with Python 3:

  * corpus integrity -- every expected causal chain is actually backed by
    adjacent source atoms, so no fixture asks the engine to invent a bridge;
  * corpus size against the brief's minimums;
  * cross-source candidates really span two documents;
  * expectation plausibility for learner cases (a 'supported' case must have a
    candidate claim in the corpus; a 'notAddressed' case must not);
  * package hygiene -- no UI framework imports, balanced delimiters, no
    god-object files, deterministic-id discipline.

Exit code is non-zero if any hard check fails.
"""
import argparse
import json
import pathlib
import re
import sys

STOP_WORDS = {
    "a", "an", "the", "of", "to", "in", "on", "at", "for", "and", "or", "is", "are", "be", "been",
    "was", "were", "it", "its", "this", "that", "these", "those", "as", "by", "with", "from",
    "into", "than", "then", "so", "such", "we", "you", "your", "our", "their", "they", "he",
    "she", "will", "would", "can", "could", "do", "does", "did", "has", "have", "had", "but",
    "if", "when", "which", "what", "there", "here", "about", "each", "any", "all", "also",
}
SUFFIXES = ["ing", "ies", "es", "s", "ed"]


def stem(word):
    for suffix in SUFFIXES:
        if len(word) > len(suffix) + 2 and word.endswith(suffix):
            return word[: -len(suffix)]
    return word


def content_tokens(text):
    raw = re.split(r"[^0-9A-Za-z_-]+", text.lower())
    return [stem(t) for t in raw if t and t not in STOP_WORDS and len(stem(t)) > 1]


def node_key(label):
    tokens = content_tokens(label)
    if tokens:
        return "-".join(tokens)
    return "-".join(t for t in re.split(r"[^0-9A-Za-z_-]+", label.lower()) if t)


def overlap(left, right):
    a, b = set(content_tokens(left)), set(content_tokens(right))
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


FACTUAL_ROLES = {"compactExplanation", "explanation", "caution", "example"}


def audit_corpus(corpus):
    failures, warnings, stats = [], [], {}
    atoms = corpus["atoms"]
    by_key = {a["key"]: a for a in atoms}
    stats["atoms"] = len(atoms)
    stats["documents"] = len(corpus["documents"])

    # Edges the graph builder will actually create.
    edges = {}
    for atom in atoms:
        if atom["role"] not in FACTUAL_ROLES or atom["isNegated"]:
            continue
        edges.setdefault((node_key(atom["subject"]), node_key(atom["object"])), []).append(atom["key"])
    stats["edges"] = len(edges)
    stats["nodes"] = len({n for pair in edges for n in pair})

    # Every chain adjacency must be a real edge.
    for chain in corpus["chains"]:
        labels = chain["labels"]
        if node_key(labels[0]) != node_key(chain["start"]):
            failures.append(f"chain {chain['key']}: start does not match first label")
        for left, right in zip(labels, labels[1:]):
            if (node_key(left), node_key(right)) not in edges:
                failures.append(f"chain {chain['key']}: no source atom joins '{left}' -> '{right}'")
    stats["chains"] = len(corpus["chains"])

    # Cross-source candidates must reference real atoms in different documents.
    for candidate in corpus["crossSourceCandidates"]:
        first, second = by_key.get(candidate["first"]), by_key.get(candidate["second"])
        if not first or not second:
            failures.append(f"cross-source {candidate['key']}: unknown atom key")
            continue
        if first["doc"] == second["doc"]:
            failures.append(f"cross-source {candidate['key']}: both atoms are from {first['doc']}")
    stats["crossSourceCandidates"] = len(corpus["crossSourceCandidates"])

    # Learner-case expectation plausibility.
    cases = corpus["learnerCases"]
    stats["learnerCases"] = len(cases)
    stats["paraphrases"] = sum(1 for c in cases if c["note"].startswith("paraphrase"))
    stats["contradictions"] = sum(1 for c in cases if c["note"].startswith("contradicts"))
    stats["overgeneralisations"] = sum(1 for c in cases if c["note"].startswith("overgeneralisation"))
    for case in cases:
        best = max((overlap(case["text"], f"{a['subject']} {a['object']}") for a in atoms), default=0.0)
        if case["expectedVerdict"] == "supported" and best < 0.3:
            failures.append(f"learner {case['key']}: expected 'supported' but nothing in the corpus is close (best {best:.2f})")
        if case["expectedVerdict"] == "notAddressed" and best >= 0.3:
            failures.append(f"learner {case['key']}: expected 'notAddressed' but a claim overlaps ({best:.2f})")
        if case["expectedVerdict"] not in {"supported", "partiallySupported", "contradicted", "notAddressed", "ambiguous"}:
            failures.append(f"learner {case['key']}: unknown verdict")

    minimums = {"atoms": 100, "edges": 50, "chains": 30, "learnerCases": 30,
                "contradictions": 20, "overgeneralisations": 20, "paraphrases": 20,
                "crossSourceCandidates": 20}
    for field, minimum in minimums.items():
        if stats.get(field, 0) < minimum:
            failures.append(f"corpus size: {field} = {stats.get(field, 0)}, brief requires >= {minimum}")

    # Concept coverage across the domains the brief names.
    domains = ["javascript", "react", "http", "caching", "retry", "idempotent",
               "database", "index", "latency", "queue"]
    corpus_text = " ".join(f"{a['subject']} {a['object']} {a['span']}" for a in atoms).lower()
    missing = [d for d in domains if d not in corpus_text]
    if missing:
        warnings.append(f"domains with no explicit mention: {', '.join(missing)}")

    return failures, warnings, stats


FORBIDDEN_IMPORTS = ["SwiftUI", "UIKit", "AppKit", "ShelfCore", "CoreData", "SwiftData"]


def audit_package(package):
    failures, warnings, stats = [], [], {}
    sources = sorted((package / "Sources").rglob("*.swift"))
    tests = sorted((package / "Tests").rglob("*.swift"))
    stats["sourceFiles"] = len(sources)
    stats["testFiles"] = len(tests)
    stats["sourceLines"] = sum(len(p.read_text().splitlines()) for p in sources)
    stats["testLines"] = sum(len(p.read_text().splitlines()) for p in tests)

    for path in sources:
        text = path.read_text()
        lines = text.splitlines()
        for forbidden in FORBIDDEN_IMPORTS:
            if re.search(rf"^\s*import\s+{forbidden}\b", text, re.M):
                failures.append(f"{path.name}: imports {forbidden}; the core must stay UI- and app-free")
        if not re.search(r"^\s*import\s+Foundation\b", text, re.M):
            warnings.append(f"{path.name}: does not import Foundation")
        if len(lines) > 600:
            failures.append(f"{path.name}: {len(lines)} lines; no god objects in this package")
        for opener, closer in [("{", "}"), ("(", ")"), ("[", "]")]:
            if text.count(opener) != text.count(closer):
                failures.append(f"{path.name}: unbalanced {opener}{closer} ({text.count(opener)} vs {text.count(closer)})")
        if "UUID()" in text:
            failures.append(f"{path.name}: uses UUID(); ids in this package must be content-derived")
        if re.search(r"\bDate\(\)", text):
            warnings.append(f"{path.name}: constructs Date(); prefer injected timestamps for determinism")

    declared = set()
    for path in sources:
        for match in re.finditer(r"^(?:public |)(?:struct|enum|final class|class|protocol|actor)\s+(\w+)", path.read_text(), re.M):
            declared.add(match.group(1))
    required = ["KnowledgeAtom", "KnowledgeRelation", "KnowledgeGraph", "MechanismEngine",
                "CausalChain", "CounterfactualEngine", "ConceptModel", "MultiSourceSynthesizer",
                "ExplanationAligner", "MisconceptionType", "QuestionPlan", "ExplanationStrategySelector",
                "UnderstandingState", "SuggestionReason", "SourceRole", "GoldenCorpus",
                "ReasoningProposalProvider", "DeterministicReasoningProposalProvider",
                "AppleFoundationReasoningProposalProvider", "EvaluationHarness"]
    for name in required:
        if name not in declared:
            failures.append(f"required type {name} is not declared in the package")
    stats["declaredTypes"] = len(declared)
    return failures, warnings, stats


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", required=True)
    parser.add_argument("--corpus", required=True)
    parser.add_argument("--out")
    args = parser.parse_args()

    corpus = json.loads(pathlib.Path(args.corpus).read_text())
    corpus_failures, corpus_warnings, corpus_stats = audit_corpus(corpus)
    package_failures, package_warnings, package_stats = audit_package(pathlib.Path(args.package))

    failures = corpus_failures + package_failures
    warnings = corpus_warnings + package_warnings

    print("corpus:", json.dumps(corpus_stats, sort_keys=True))
    print("package:", json.dumps(package_stats, sort_keys=True))
    for warning in warnings:
        print("WARN:", warning)
    for failure in failures:
        print("FAIL:", failure)
    print(f"\n{len(failures)} failures, {len(warnings)} warnings")

    if args.out:
        pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        pathlib.Path(args.out).write_text(json.dumps({
            "corpus": corpus_stats,
            "package": package_stats,
            "failures": failures,
            "warnings": warnings,
        }, indent=1) + "\n")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
