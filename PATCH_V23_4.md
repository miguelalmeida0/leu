# Leu V23.4 — Unified Progress Convergence

V23.3 passed the Apple build, 182/182 core tests, 20/20 Apple PDF tests, all Reader interaction/regression tests, all main UI tests, and all world-class tests. Three Learning OS journeys still failed because Progress Now / Progress History remained separate destinations behind the secondary disclosure.

## Product correction
- Progress is now a first-class Study row.
- One Progress sheet owns two explicit views: **Now** and **History**.
- This matches the intended IA: current learning state and understanding history are two views of the same object.
- Advanced More actions (Connections, Document topics, Search ideas) remain inline, but their rows stay instantiated and become accessibility-hidden only while collapsed.
- Expansion state lives in `LearningModel`, so redraws cannot discard it.

## QA convergence
- Learning OS UI tests now open `learning-progress`, then use `progress-tab-now` / `progress-tab-history`.
- Static QA forbids a regression to separate Progress now/history destinations.
- No PDF assertions, offline guarantees, or test thresholds were weakened.
