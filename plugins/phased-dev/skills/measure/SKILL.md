---
name: measure
description: Decide between candidate methods, algorithms or libraries by measurement — decision rule fixed first, same contract, correctness first, benchmark speed and memory, reproducible report — and let the owner choose. Use for a spec choice pending M-n or any performance claim.
---

# Measure

Some choices cannot be made well on paper: which algorithm, which data
structure, which library, memory-mapped or buffered, in-memory or on disk. The
spec keeps **more than one candidate** for such a choice, with a note that it is
decided by measurement; this skill runs that measurement and gives the owner a
decision they can trust.

Read `docs/SPEC.md` (the pending decision and the contract the candidates
share), `docs/MEASUREMENTS.md`, `docs/DATA.md` (the workload), `CLAUDE.md`.
Method and pitfalls: `references/benchmark-method.md`.

## 1. Plan — before any candidate code

Write the report skeleton `docs/measurements/M-<n>.md` (template in
`MEASUREMENTS.md`) and set the index row to *running*:

- **The question** and **the decision rule, fixed before measuring**: the
  criteria in priority order with thresholds ("B unless its peak memory is over
  2× A's on the large set; within 10 % on speed goes to the simpler one"). A rule
  written after the numbers are in fits the numbers. If the spec did not state
  the rule, propose it and get the owner's agreement first.
- **The candidates**, each implementing **the same contract** from the spec.
  If they cannot share a contract, the decision is architectural, not a
  measurement — take it back to `specify`.
- **The workload**: data sets from `DATA.md` that represent real use — typical
  and the largest expected; several sizes if scaling matters. Missing data is
  generated first (`test-data`).
- **The metrics**: wall time, peak memory (RSS), and whatever the decision needs —
  throughput, allocations, latency percentiles, startup, accuracy.

## 2. Build the candidates — as small as the question allows

- Each candidate implements the contract and nothing else: the fastest honest
  version of each, not a polished one. Put throwaway candidates under
  `spikes/m<n>-<name>/`; if both may survive (Strategy pattern behind the
  contract), put them in the source tree.
- The **same harness** drives every candidate: same input, same build profile,
  same measurement code. Only the candidate changes.
- Libraries used by a candidate must be in the spec's *Allowed libraries*, or be
  a question — a candidate library is a decision point, not a free choice.

## 3. Correctness first

Before timing anything, every candidate must produce the **same, correct**
output on the whole workload — the conformance test or an output hash
(`scripts/measure.sh` prints one per run). A candidate that is fast because it
is wrong is disqualified, and the report says so.

## 4. Measure

- Whole-program runs: `scripts/measure.sh -n <runs> -w <warm-up> -l <candidate>
  -o docs/measurements/M-<n>/results.csv -- <command>` — wall time, peak RSS,
  exit status and output hash per run; min/median/max summary.
- Finer resolution (functions, sub-millisecond work): the language's benchmark
  harness (criterion, pytest-benchmark, JMH, Google Benchmark, `go test
  -bench`), or `hyperfine` for commands. Allocations and memory profiles:
  heaptrack, valgrind massif, the runtime's allocator stats.
- Release build, same machine, nothing else heavy running; enough runs that the
  spread is small relative to the difference; state warm vs cold cache and
  measure both when the choice depends on I/O.
- Record the environment (machine, CPU, RAM, OS, toolchain and versions, build
  flags) — a number without its environment cannot be reproduced or compared.

## 5. Report and hand over

Fill the report: results table, raw data committed next to it (small CSVs),
the exact commands to reproduce, threats to validity, and a **recommendation by
the decision rule**. Set the index row to *reported* and commit
(`T<id>: M-<n> measured` if it is a plan task, else `P<N>: M-<n> measured`).

Then present it to the owner — the numbers, the rule, the recommendation, and
what the losing candidate would still be good for — and ask for the decision
(AskUserQuestion: the candidates as options, the recommended one first). The
owner may choose against the recommendation; record why.

## 6. Close

- Spec: replace the candidate list with the chosen one; add `D-n` to the
  decision log citing `M-n`; the level stays confirmed.
- Index row: *decided*, with the D-n.
- The loser: deleted, or kept behind the contract if the owner wants the option
  (then it needs tests like any other implementation).
- Tasks that were waiting on the decision (`prepare-phase` held them) can now be
  prepared.

## Measured claims everywhere

Every performance statement in the project — in the spec, STATUS, a commit
message, a comment — cites an `M-n` or is removed. Production quality targets
are checked with the same method at the production gate, and a regression is a
new measurement, not an argument.
