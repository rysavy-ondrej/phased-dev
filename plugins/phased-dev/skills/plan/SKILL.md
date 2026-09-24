---
name: plan
description: Step 3 of the phased-dev method — write docs/IMPLEMENTATION_PLAN.md as phases with runnable exit criteria, tasks with small-scale tests, a readiness check per phase, settled decisions, and (prototype profile) a Batches table that groups tasks to be implemented, committed and verified together to save tokens. Use after specify, before any phase is implemented, or when a plan needs re-cutting.
---

# Plan

Goal: a plan an agent can execute without rediscovering anything, where every
phase ends in something runnable and checkable.

Read `CLAUDE.md`, `docs/CONCEPT.md`, `docs/TEST_DATA.md` and the profile in
`scripts/method.conf`.

## 1. Phases

Each phase ends with a **runnable program** and adds capability without
restructuring what came before. Phase 0 is the skeleton: the full interface of
the final tool (unimplemented options refuse with a clear "not implemented in
this phase"), configuration, diagnostics, error taxonomy. Order phases so each
one's output is observable, and so seams are fixed before anything hangs off
them.

Every phase has:
- **Goal** — one sentence.
- **Phase exit** — a command and what it must produce, on real data. Not "works
  well". It will become `scripts/phase<N>-gate.sh`, written at the phase's first
  task, before the code it grades.
- **Readiness** — checked before the run: which fixtures exist for it (so
  nobody hand-builds what real data already covers), dependencies it adds,
  owner decisions it waits on, interface that already exists. Each finding is
  either *decided* (with a settled decision) or *recorded so the run does not
  re-derive it*.

A phase wider than ~8 tasks, or mixing a foundational seam with the things built
on it, is split into parts (`### Part 3A — ...`), each gated on its own; a part
that produces nothing observable runs without a gate and is gated with the next.

## 2. Tasks

`- ☐ **T<phase>.<n> Title.** Requirement.` Each requirement is precise enough
that a verifier can quote it and answer met / partially met / unmet. Each names
its **small-scale test**: the test that would fail if the behaviour were broken,
and its test target. Name the authority's fixtures the task must use.

Put a task in the plan rather than inside another when it touches everything (a
refactor) or when it is the most consequential signature in the project — riding
along with other work is how both go wrong at once.

## 3. Batches (prototype — required; production — optional "groups")

Before any code, cut each phase into batches. This is where the prototype's
token savings come from: the dominant cost of an agent is reading context, and a
batch pays for one read across several tasks, one commit, and one verification.

A batch is a set of tasks that:
1. **share context** — the same module or files, so one implementer holds them;
2. **are verified together** — one command or test file demonstrates all of them;
3. **have one demonstrable outcome** — something the verifier can run.

Rules:
- 2–6 tasks per batch; size each S/M/L by how much must be read and written.
- **A task that is foundational or correctness-critical gets a batch of its
  own** (the seam everything depends on; the component with a bounded-memory or
  security requirement). A verifier splitting attention is how such a
  requirement goes unobserved.
- A batch never spans a seam boundary and the things built on it.
- Order batches so each starts from a green, committed predecessor.
- Record the table under the phase:

```markdown
### Batches

| Batch | Tasks | Shared context | Verified together by | Size |
| --- | --- | --- | --- | --- |
| B2.1 | T2.1, T2.2, T2.3 | src/decode/link.rs | `cargo test --test link` + `prog --dump flow` on data/x | M |
| B2.2 | T2.4 | src/decode/reassembly.rs (bounded memory) | `cargo test --test reassembly` | L |
```

Estimate the phase's cost in agent runs: prototype ≈ batches × (1 implementer +
1 verifier + ≤1 repair/recheck pair) + gate + 1 review + triage. If that is
disproportionate to the question, cut scope (park) before cutting verification.

## 4. Scope pass (prototype)

Walk every task against *the question* in `CONCEPT.md`. A task that does not
serve it is removed and parked (`park` skill). A task that serves it partly is
narrowed **in the plan text**, with the removed part parked — never narrowed
silently during implementation. Hardening a production plan would contain
(fuzzing, hostile-input suites, benchmarks, portability) is listed under
*Deferred hardening* in `OUT_OF_SCOPE.md` instead of becoming tasks.

## 5. Settled decisions

Every choice made while planning that someone might later reopen: a row with
the decision, the reason, the measurement behind it, who ruled and when, and
what would reopen it. Owner decisions come from the owner; propose, do not rule.

## 6. Gate scripts

For each phase, create `scripts/phase<N>-gate.sh` from `scripts/phase0-gate.sh`
— or note in the phase's first task that it must be written first. Update
`scripts/method.conf` commands if the plan adds build variants or features.

## 7. Review with the owner

Show the phase list, the batches, the readiness decisions that need a ruling, and
the estimated agent runs for the first phase. Then `implement`.
