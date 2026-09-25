# Measurements

Decisions that depend on performance — speed, memory, sometimes accuracy — are
not taken on opinion. The spec records the candidates and a measurement plan;
a measurement task runs **before** anything depends on the choice; the owner
decides from the report (`measure` skill). Every performance claim anywhere in
the project cites an `M-n` from here.

## Index

| # | Decides | Candidates | Status | Report | Decision |
| --- | --- | --- | --- | --- | --- |
<!-- | M-1 | flow-table structure | A: hash map · B: sorted vec | planned | — | — | -->

Statuses: **planned** (in the spec, task not run) · **running** · **reported**
(waiting for the owner) · **decided** (D-n in the spec's decision log) ·
**reopened** (new evidence; see the report).

<!--
Each measurement has its own report, docs/measurements/M-<n>.md:

# M-1 — <what is decided>

**Spec:** <SPEC.md section, D-n pending> · **Task:** T1.4 · **Date:** <YYYY-MM-DD>

## Question and decision rule
<The question. The criteria, in priority order, with thresholds — decided
BEFORE measuring: "choose B unless its peak memory exceeds 2x A's on the
large set; tie on speed (within 10 %) goes to the simpler candidate">

## Candidates
| | Candidate | Implements (contract) | Where |
| --- | --- | --- | --- |
| A | ... | FlowTable | spikes/m1-hashmap/ or src/.../hash.rs |

## Workload
<Data sets from DATA.md (which files, sizes), and why they are representative;
cold or warm cache; input sizes varied if scaling matters.>

## Environment
<machine, CPU, cores, RAM, OS/kernel, toolchain and versions, build profile and
flags, other load on the machine>

## Correctness first
<Every candidate produces the same (correct) output on the workload: how it
was checked (output hash, conformance test). A candidate that is fast because
it is wrong is disqualified here.>

## Results
| Candidate | Workload | Runs | Wall median (min–max) | Peak memory median | Other (allocs, throughput) |
| --- | --- | --- | --- | --- | --- |

Raw data: docs/measurements/M-1/ (csv) · Reproduce: <exact commands>

## Threats to validity
<Warm vs cold cache, timer resolution, input not representative, noisy
machine, one platform only ...>

## Recommendation
<Candidate, by the decision rule, in one paragraph. What the loser would still
be good for (keep behind the same contract, or delete).>

## Owner decision
<D-n, owner, date — filled in when decided>
-->
