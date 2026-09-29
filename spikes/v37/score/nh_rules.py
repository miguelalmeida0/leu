"""V37 NH holdout (throwaway): the per-author and whole-set rules HOLDOUT_PLAN adds to the gate rules.
Authors Q–V take the primary gate's author quotas (Q from J, R from K, S from L, T from M, U from N, V from O),
plus causal reversals and explicit `reasoningIssue` labels."""
from spike_rules import QUOTAS, STATE_RANGES, GATE_MINIMUMS, GATE_STATE_MINIMUMS

AUTHORS = ["Q", "R", "S", "T", "U", "V"]
BASE = dict(zip(AUTHORS, ["J", "K", "L", "M", "N", "O"]))
CAUSAL_REVERSAL = {"Q": 2, "R": 1, "S": 3, "T": 2, "U": 6, "V": 2}
# reasoningIssue=true, and reasoningIssue=true on a misconception case ("both"), per author.
REASONING = {"Q": (6, 2), "R": (6, 1), "S": (8, 4), "T": (8, 2), "U": (24, 5), "V": (8, 2)}
NH_QUOTAS = {a: dict(QUOTAS[BASE[a]], causalReversal=CAUSAL_REVERSAL[a]) for a in AUTHORS}
NH_STATE_RANGES = {a: STATE_RANGES[BASE[a]] for a in AUTHORS}
NH_MINIMUMS = dict(GATE_MINIMUMS, causalReversal=16)
NH_STATE_MINIMUMS = dict(GATE_STATE_MINIMUMS)
NH_REASONING_MIN, NH_BOTH_MIN = 60, 16
# Tags that describe a reasoning fault: HOLDOUT_PLAN's reasoningIssue is true for them by definition.
REASONING_TAGS = {"rightConclusionWrongReasoning", "wrongConclusionPlausibleReason", "causeVsCorrelation"}
assert sum(CAUSAL_REVERSAL.values()) >= 16 and sum(r for r, _ in REASONING.values()) >= 60 and sum(b for _, b in REASONING.values()) >= 16


def is_misconception(case):
    return case.get("state") == "misconception" or bool(case.get("misconceptions"))


def coarse(case):
    if is_misconception(case):
        return "misconception"
    return "positive" if case.get("state") in ("understood", "mostlyUnderstood") else "weak"
