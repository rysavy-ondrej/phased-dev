---
name: prepare-phase
description: Prepare one phase of the phased-dev plan immediately before implementing it — fix the task order and dependencies, group tasks that share context, make sure every question affecting the phase is answered, locate fixtures and data, write the phase's gate script, and mark the phase Prepared. Use before implementing any phase; an unprepared phase must not be started.
---

# Prepare a phase

Preparation happens once, just before the phase, when the code it builds on
exists. It is what lets the implementation run without rediscovering anything —
and it is where questions get answered, not halfway through a task.

Read `CLAUDE.md`, the phase in `docs/IMPLEMENTATION_PLAN.md`, the previous
phase's STATUS and backlog, `docs/QUESTIONS.md`, `docs/FEATURES.md`.

## 1. The tasks are still right

The previous phase may have changed things. For each task: is it still needed,
still correctly worded, still in the right mode? Features the owner has
disposed as `planned: T<this phase>.n` become tasks now. Changes to the task
list are proposed to the owner, not made silently.

If the phase is an outline (a later mode), write its tasks now with the `plan`
skill's rules.

## 2. Order and dependencies

Read the code the phase builds on. Then fix the order:
- foundations first — an interface before its users, a parser before what
  consumes its output;
- each task starts from a green, committed predecessor;
- the riskiest task early, so a wrong assumption surfaces before work piles on it.

Group tasks that **share context** (same module or files) into implementation
groups `G1, G2 …`: one implementer session holds a group, but each task is still
its own commit. A foundational or correctness-critical task (the seam
everything uses; a component with a memory or security bound) is a group of its
own. In prototype mode, one verifier takes a whole group; in the other modes
verification is per task.

Write the *Preparation* table under the phase: order, task, depends on, group,
why here. Reorder the task lines to match if needed.

## 3. Questions answered first

- Every open `Q-n` that affects this phase must be answered before the phase
  starts — including non-blocking ones raised in the previous phase, whose
  assumption may be wrong. Collect them and ask the owner in one round.
- Look for new ones now: read each task against the spec and the code. A library
  not in *Allowed libraries*, an ambiguity in the requirement, a choice between
  two designs — ask now, record in `docs/QUESTIONS.md`.
- An answer that contradicts earlier work becomes a task in this phase.

`scripts/progress.sh questions` lists what is open.

## 4. Fixtures, data, traps

Which existing data covers this phase's tasks (so nobody hand-builds what real
data already provides), which the phase must create, which dependencies it adds
(they must be in the spec's allowed list), which existing interface it wires into.
Write each finding once, under *Traps and findings*.

## 5. The gate script

Write `scripts/phase<N>-gate.sh` now, before the code it grades: the phase exit
criterion as runnable checks on real data. It fails until the phase is done,
which is correct. Every check must fail when its setup fails ("graded nothing"),
never pass on empty output.

## 6. Mark prepared

Add `Prepared: <YYYY-MM-DD>` under the phase heading (`gate.sh` requires it),
update `docs/STATUS.md` → *Current run*, commit as `P<N>: prepare phase <N>`.
Tell the owner the order, the groups, and an estimate of agent runs: tasks ×
(implementer share + verifier) + gate + review. Then `implement`.
