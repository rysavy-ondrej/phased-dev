---
name: method
description: Overview of the phased-dev method — the lifecycle from concept to documented release, the two profiles (production and prototype), and which phased-dev skill to use at each step. Use when starting a new project with this method, when unsure which step comes next, or when asked how the method works.
---

# The phased-dev method

A way of building software with agents that stays honest under scale: one
constitution every agent reads (`CLAUDE.md`), a plan of phases with runnable exit
criteria, one commit per unit of work, independent verification, mechanical
checks as scripts, and registers that make every known gap visible.

It was extracted from a project (maestro-enjoy, a from-scratch reimplementation
held to output parity with a reference) where each rule was bought by a measured
failure. `references/lessons.md` has the evidence; read it when a rule seems
excessive before relaxing it.

## Lifecycle

| Step | Skill | Produces | Done when |
| --- | --- | --- | --- |
| 1. Conceive | `conceive` | `docs/CONCEPT.md`, profile choice, scaffolded repo | purpose, authority, priorities, in/out scope and (prototype) *the question* are written and the owner agrees |
| 2. Specify | `specify` | `CLAUDE.md` invariants, seams, output contract; `docs/PROVENANCE.md`, `docs/TEST_DATA.md` | every invariant cites the authority; test data is located or listed as missing |
| 3. Plan | `plan` | `docs/IMPLEMENTATION_PLAN.md` with phases, tasks, exit criteria, (prototype) batches, settled decisions | each phase has a runnable exit criterion and a readiness section |
| 4. Implement | `implement` | commits on `main`, one per task or batch, each audited and independently verified | `scripts/task-audit.sh` is clean and the verifier passed |
| 5. Gate | `gate` | `scripts/gate.sh <n>` green, review findings triaged, `docs/STATUS.md` updated, push | the exit criterion passes on real data, no blocker |
| 6. Document | `registers` | STATUS, BACKLOG, DIVERGENCES, UNVALIDATED, OUT_OF_SCOPE, history | continuous — every step writes to them |
| any time | `park` | an `OOS-n` entry | a feature outside the question was recorded instead of built or dropped |

Steps 4–5 repeat per phase. Steps 1–3 are revisited when a phase finds that an
assumption was wrong — the plan is edited in the open (a new task, a settled
decision), never worked around.

## Profiles

Chosen at *Conceive*, recorded in `CLAUDE.md` and `scripts/method.conf`.
Full comparison: `references/profiles.md`.

- **production** — the output is trusted by others. Per-task (or planned-group)
  adversarial verification with mutation proof of every test, hostile-input
  testing and fuzzing, a four-lens review panel plus a completeness critic at
  each gate.
- **prototype** — the project exists to answer a question. Three adjustments:
  1. **Harness proportional to the question.** Test every claim the answer rests
     on; skip fuzzing, malformed-input suites, polish, portability. Each skipped
     item is one line under *Deferred hardening*.
  2. **Token-conservative, batch-first.** Before implementation, each phase is cut
     into batches of tasks that share context and are verified together. One
     batch → one implementer → one commit → one verifier → at most one repair.
     One combined review per phase instead of a panel.
  3. **Out-of-scope register.** Features that appear during specification or
     development and do not serve the question are parked in
     `docs/OUT_OF_SCOPE.md` — not built, not silently dropped — and the code
     refuses them visibly if input reaches them.

  What a prototype never relaxes: the prime directive, never lying in the output,
  no hollow test for a claim that is made, and *failure is a stop*.

**Graduation** (prototype → production) is a phase of its own, planned with the
`plan` skill: switch the profile, turn *Deferred hardening* into tasks, rule on
every parked entry, close or re-justify every `UNVALIDATED.md` entry.

## Rules that hold in every step

- `CLAUDE.md` is the single home of a rule. Prompts and skills name the rule;
  they do not restate it (a restatement is a second, weaker source).
- The authority wins over prose and judgement. Disagreement is filed, not fixed
  silently.
- Anything mechanical is a script. Anything needing judgement is an agent.
- Failure is a stop: report the exact output and the likely cause.
- Owner decisions are dated rulings in the plan's *Settled decisions*, with the
  measurement behind them.
