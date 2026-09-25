---
name: implement
description: Step 4 of the phased-dev method — execute a phase of docs/IMPLEMENTATION_PLAN.md task by task (production) or batch by batch (prototype) on linear main, with tests in the same commit, scripts/task-audit.sh, an independent adversarial verifier, and bounded repair rounds; stop and report on failure. Use when the user asks to implement a task, batch or phase of a plan written with this method.
---

# Implement

Read `CLAUDE.md` (binding), the phase in `docs/IMPLEMENTATION_PLAN.md` including
its *Readiness* and *Batches*, and `scripts/method.conf` for the profile and the
commands.

**Before the first unit:** the tree is clean and green, the phase's
`scripts/phase<N>-gate.sh` exists (write it first if not — it grades the phase
and must exist before the code it grades), and every readiness item marked as
needing a decision has one. Missing any of these is a stop.

## Two ways to run

**A. The `run-phase` workflow** (scaffolded into `.claude/workflows/`). Use it
when the user asks to run a whole phase unattended. Args:
`{phase: 2, profile: "prototype"}`; `{only: ["T2.3"]}` to re-run tasks;
`{groups: [[...]]}` to override batches; `{skipReview: true}` to land work
without the gate. It stops on the first blocked unit and returns why. It spawns
many agents; say so and confirm before a production run.

**Skip the Scope agent for small re-runs.** Scope reads the whole plan and the
relevant source to write each task's brief — a fixed cost of the same order as
implementing one task, which a run of one or two tasks cannot amortise. When you
already know the tasks (a single remediation task, a re-run after a block),
write the briefs yourself and pass them:

```js
{
  phase: 3,
  tasks: [{
    id: "T3.17",
    slug: "reused-5-tuple",
    spec: "<the plan requirement, quoted verbatim, plus the context the implementer needs: file:line it starts from, the invariant or settled decision it touches>",
    smallScale: "<the test that would fail if the behaviour broke, naming its target>",
  }],
  phaseExit: "<quoted from the plan, if the gate will run>",
  notes: "<readiness items and traps that apply>",
  skipReview: true,   // unless this run should also close the phase
}
```

The brief is only as good as what you put in it: quote the requirement
verbatim and name the code it extends, or the implementer builds a parallel
scheme. Passing `tasks` also bypasses the plan's Batches table: under the
prototype profile the supplied tasks run as **one batch**, so pass `groups` if
they should be split. For a single task
with no need to run unattended, prefer mode B below, which skips both Scope and
the implementer agent.

**B. In session** — the default for a prototype and for single tasks. The main
session is the implementer (no subagent: the context is already loaded), and one
independent verifier agent checks each unit. Steps below.

## The loop, per unit (a task, or a prototype batch)

1. **Implement** the unit's tasks. Real code; no placeholders except a runtime
   "not implemented in this phase" refusal where the plan asks for one.
2. **Tests in the same commit.** Fixtures are literal data, never the constant
   under test; a new table of magic numbers gets a test pinning each value to a
   literal with its citation. Run the targeted tests while working, the full
   suite once at the end.
   - *production*: mutation-prove every test you add — break the
     implementation, run that one test, watch it fail, revert.
   - *prototype*: write each test to fail if its behaviour broke; note, per task,
     the single assertion the claim rests on. The verifier mutation-proves those.
3. **Scope (prototype).** A feature outside the question came up? Use `park`:
   record it, make the code refuse it visibly if input can reach it, continue.
   Never park something the unit's own requirement asks for — that is a stop.
4. **Tick** the unit's checkboxes (☐ → ☑) — those lines only (a sed on `T1.1`
   also hits `T1.10`; check the diff).
5. **Commit once**: `T2.1, T2.2, T2.3: <what>` (or `T1.3: <what>`), with the
   trailer. Linear `main`, no branch, no amend, no push.
6. **Audit**: `scripts/task-audit.sh <id>` for each task id. It checks subject,
   trailer, clean tree, protected paths, checkbox ownership, unpushed, and runs
   the checks. Fix with a further commit carrying the same id list.
7. **Verify** — spawn one Agent (general-purpose, high effort) with the prompt
   in `references/verifier-prompt.md`, filled for this unit. It is read-only and
   adversarial. A verifier that returns nothing verified nothing: re-run it,
   never count it as a pass.
8. **Repair** reproduced problems with a further commit (same id list), proving
   each fix by mutation and adding the test that would have caught it. Then a
   **recheck** agent checks only that problem list and the repair diff
   (`references/verifier-prompt.md`, recheck section). Max rounds: production 3,
   prototype 1. Problems that survive are a stop.
9. **Observations** the verifier returns (non-blocking) are kept for the phase's
   triage — append them to a running list in the session, or straight into
   `docs/BACKLOG.md` under the phase.
10. Update the phase row in `docs/STATUS.md` in the unit's commit when the unit
    changes what the project can do.

## Failure is a stop

When the unit cannot be completed — approach fails, a test fails with no obvious
fix, the authority will not match, a plan assumption is wrong — stop and report:
what was attempted, the exact failure output, the likely cause, and what
decision is needed. Do not commit red, weaken a test, record a real diff as a
divergence to get past it, skip ahead, or narrow scope silently.

## Token discipline while implementing

- Do not re-read what the plan's readiness section already established.
- Do not run the whole suite repeatedly; determinism belongs to the gate.
- Do not restate CLAUDE.md in agent prompts — agents read it; name the section.
- Prototype: one implementer context per batch; one verifier per batch.
