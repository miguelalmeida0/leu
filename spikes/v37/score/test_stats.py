#!/usr/bin/env python3
"""Tests for stats.py on synthetic score files (THROWAWAY, V37 spike). Run: python3 -m unittest test_stats"""
import contextlib
import io
import json
import os
import tempfile
import unittest

import stats


def report(cases=240, coarse=180, paraphrase=(40, 50), novel=(40, 50), wr=(30, 50, 40), committed=(120, 110), probes=120,
           false_mastery=(5, 160), harmful=10):
    return {"cases": cases, "coarseRight": coarse, "weakReasoningDetected": wr[0], "goldWeakReasoning": wr[1],
            "predictedWeakReasoning": wr[2], "committed": committed[0], "committedRight": committed[1], "probes": probes,
            "falseMastery": false_mastery[0], "goldNotPositive": false_mastery[1], "harmfulWrites": harmful,
            "perCategory": {"paraphrase": {"n": paraphrase[1], "right": paraphrase[0]},
                            "novelVocabulary": {"n": novel[1], "right": novel[0]}}}


def score(label, primary_report, baseline_report=None, signatures=None, latency=None, failures=None, canonical_passed=None):
    signatures = signatures or {f"J-{i:02d}": "understood|false|true|false" for i in range(1, 41)}
    per_case = {name: {cid: {"signature": sig, "coarseRight": True, "exactRight": True} for cid, sig in signatures.items()}
                for name in ("A", "D")}
    result = {"label": label, "set": "PG", "cases": 240, "blind": True,
              "reports": {"A": baseline_report or report(coarse=122, false_mastery=(10, 160), harmful=30), "D": primary_report},
              "perCase": per_case, "failures": failures or {"cases": 240, "schemaError": 1, "refused": 0, "timeout": 0},
              "latency": latency or []}
    if canonical_passed is not None:
        result["canonical"] = {"D": {"passed": canonical_passed, "cases": 5}}
    return result


class StatisticsTests(unittest.TestCase):
    def test_wilson_matches_known_values(self):
        low, high = stats.wilson(8, 10)
        self.assertAlmostEqual(low, 0.4902, places=3)
        self.assertAlmostEqual(high, 0.9433, places=3)
        self.assertEqual(stats.wilson(0, 0), (0.0, 0.0))

    def test_exact_mcnemar(self):
        self.assertEqual(stats.mcnemar_exact(0, 0), 1.0)
        self.assertAlmostEqual(stats.mcnemar_exact(0, 6), 0.03125)
        self.assertAlmostEqual(stats.mcnemar_exact(1, 9), 2 * 11 / 1024)
        self.assertEqual(stats.mcnemar_exact(5, 5), 1.0)

    def test_nearest_rank_p95(self):
        self.assertEqual(stats.p95(list(range(1, 21))), 19)
        self.assertEqual(stats.p95(list(range(100, 0, -1))), 95)
        self.assertEqual(stats.p95([7]), 7)
        self.assertIsNone(stats.p95([]))

    def test_bootstrap_of_identical_runs_is_zero(self):
        self.assertEqual(stats.bootstrap_difference([1, 0, 1, 1], [1, 0, 1, 1]), (0.0, 0.0))
        low, high = stats.bootstrap_difference([0] * 50, [1] * 50)
        self.assertEqual((low, high), (1.0, 1.0))

    def test_metrics_follow_the_preregistered_definitions(self):
        m = stats.metrics(report(wr=(0, 50, 0)), {"cases": 240, "schemaError": 3, "refused": 1, "timeout": 2})
        self.assertEqual(m["G5"], (0, 0))
        self.assertEqual(stats.ratio(*m["G5"]), 0.0, "precision is 0 when nothing is predicted")
        self.assertEqual(m["G9"], (10, 240))
        self.assertEqual(m["G11"], (3, 240))

    def test_weak_reasoning_is_scored_apart_from_the_state(self):
        exact = stats.metrics(report(wr=(10, 50, 12)))
        independent = stats.metrics(report(wr=(10, 50, 12)), None, {"gold": 64, "predicted": 30, "detected": 24})
        self.assertEqual(exact["G4"], (10, 50))
        self.assertEqual(independent["G4"], (24, 64), "a reasoning issue inside a misconception still counts")
        self.assertEqual(independent["G5"], (24, 30))


class AuthorTests(unittest.TestCase):
    def test_blind_author_breakdown_refuses_per_case_groups(self):
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "s.json")
            blind = score("s", report(), signatures={"a1": "x", "a2": "x"})
            with open(path, "w", encoding="utf-8") as handle:
                json.dump(blind, handle)
            with self.assertRaises(SystemExit):
                stats.authors(path, "D")
            blind = score("s", report())
            with open(path, "w", encoding="utf-8") as handle:
                json.dump(blind, handle)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                stats.authors(path, "D")
            self.assertIn("J=40/40", out.getvalue())


class GateTests(unittest.TestCase):
    def run_gate(self, files):
        with tempfile.TemporaryDirectory() as directory:
            paths = {}
            for name, content in files.items():
                paths[name] = os.path.join(directory, name + ".json")
                with open(paths[name], "w", encoding="utf-8") as handle:
                    json.dump(content, handle)
            argv = ["gate", "--primary", "D", "--mac", paths["m1"], paths["m2"], paths["m3"], "--iphone", paths["i"],
                    "--cold", paths["cold"], "--canonical", paths["c1"], paths["c2"], paths["c3"], paths["ci"]]
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                code = stats.main(argv)
            return code, out.getvalue()

    def files(self, warm_ms=5_000, cold_ms=11_000, launches=20, primary=None, canonical=5):
        warm = [{"words": 40, "cold": False, "processCallIndex": i, "totalMs": warm_ms} for i in range(1, 60)]
        cold = [{"words": 40, "cold": True, "processCallIndex": 0, "totalMs": cold_ms} for _ in range(launches)]
        good = primary or report()
        files = {name: score(name, good) for name in ("m1", "m2", "m3")}
        files["i"] = score("i", good, latency=warm)
        files["cold"] = score("cold", good, latency=cold)
        for name in ("c1", "c2", "c3", "ci"):
            files[name] = score(name, good, canonical_passed=canonical)
        return files

    def test_a_clean_pass(self):
        code, out = self.run_gate(self.files())
        self.assertEqual(code, 0, out)
        self.assertIn("GATE PASS", out)
        self.assertNotIn("J-01", out, "no case id is ever printed")

    def test_latency_gates_fail_separately_and_flag_their_bands(self):
        code, out = self.run_gate(self.files(warm_ms=13_000))
        self.assertEqual(code, 1)
        self.assertRegex(out, r"G16-warm\s+FAIL")
        self.assertRegex(out, r"G16-cold\s+PASS")
        code, out = self.run_gate(self.files(warm_ms=8_000, cold_ms=15_000))
        self.assertEqual(code, 0)
        self.assertIn("UX problem", out)
        self.assertIn("prewarming", out)
        code, out = self.run_gate(self.files(cold_ms=21_000))
        self.assertRegex(out, r"G16-cold\s+FAIL")
        code, out = self.run_gate(self.files(launches=19))
        self.assertRegex(out, r"G16-cold\s+FAIL")

    def test_worst_run_counts_and_baseline_relative_gates(self):
        files = self.files()
        files["m2"] = score("m2", report(coarse=160))  # 66.7% < 70% on one run
        code, out = self.run_gate(files)
        self.assertEqual(code, 1)
        self.assertRegex(out, r"G1\s+FAIL\s+worst 66\.7% \(m2\)")
        code, out = self.run_gate(self.files(primary=report(false_mastery=(11, 160))))
        self.assertRegex(out, r"G8\s+FAIL")
        code, out = self.run_gate(self.files(canonical=4))
        self.assertRegex(out, r"G10\s+FAIL")

    def test_consistency_needs_identical_signatures(self):
        files = self.files()
        changed = {f"J-{i:02d}": "understood|false|true|false" for i in range(1, 41)}
        changed["J-01"] = "fragile|true|false|false"
        files["m3"] = score("m3", report(), signatures=changed)
        code, out = self.run_gate(files)
        self.assertRegex(out, r"G14\s+PASS\s+39/40")  # 97.5% ≥ 97%
        self.assertNotIn("J-01", out)


if __name__ == "__main__":
    unittest.main()
