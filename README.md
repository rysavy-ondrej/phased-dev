# phased-dev

A reusable, phased, gate-driven development method for software built with
Claude Code agents — from concept through specification, planning,
implementation and testing to documentation. Packaged as a Claude Code plugin.

Extracted from the maestro-enjoy project, where every rule was added after a
measured failure (`plugins/phased-dev/skills/method/references/lessons.md`).

## Install

```bash
claude plugin marketplace add /root/phased-dev
claude plugin install phased-dev@phased-dev
```

Or, inside Claude Code: `/plugin marketplace add /root/phased-dev`, then
`/plugin install phased-dev@phased-dev`. Push this folder to a git host to share
it; the marketplace can then be added by its URL.

## Lifecycle

| Step | Skill | Output |
| --- | --- | --- |
| overview | `/phased-dev:method` | which step comes next; profiles |
| 1 | `/phased-dev:conceive` | `docs/CONCEPT.md`, profile, scaffolded repo |
| 2 | `/phased-dev:specify` | `CLAUDE.md` invariants, seams, output contract; test-data provenance |
| 3 | `/phased-dev:plan` | `docs/IMPLEMENTATION_PLAN.md`: phases, exit criteria, readiness, batches |
| 4 | `/phased-dev:implement` | one commit per task/batch, audited and independently verified |
| 5 | `/phased-dev:gate` | full-scale test, review, triage, STATUS, push |
| always | `/phased-dev:registers` | STATUS, BACKLOG, DIVERGENCES, UNVALIDATED, PROVENANCE |
| any time | `/phased-dev:park` | an out-of-scope entry instead of a built or dropped feature |

## Profiles

- **production** — per-task adversarial verification with mutation proof,
  hostile-input tests and fuzzing, a four-lens review panel plus critic.
- **prototype** — for experimental projects that exist to answer a question:
  1. harness proportional to the question (no fuzzing/hardening; each skipped
     item recorded as *Deferred hardening*);
  2. token-conservative: tasks are grouped into **batches planned before
     implementation**, each implemented, committed and verified once;
  3. an **out-of-scope register** (`docs/OUT_OF_SCOPE.md`) for features that
     come up during spec and development but are outside the prototype.

Both keep: the authority wins, never lie in the output, no hollow tests,
failure is a stop, linear history, the push is the gate.

## What a project gets

`plugins/phased-dev/scripts/scaffold.sh <dir> <production|prototype>` (run by
the `conceive` skill) installs, without overwriting anything:

```
CLAUDE.md                        the constitution every agent reads
docs/CONCEPT.md                  why, for whom, in/out, the question
docs/IMPLEMENTATION_PLAN.md      phases, tasks, batches, settled decisions
docs/STATUS.md BACKLOG.md DIVERGENCES.md UNVALIDATED.md
docs/PROVENANCE.md TEST_DATA.md  (+ OUT_OF_SCOPE.md for prototypes)
scripts/method.conf              profile + the project's check commands
scripts/task-audit.sh            per-task working-agreement audit (mechanical)
scripts/gate.sh                  per-phase universal gate (mechanical)
scripts/phase0-gate.sh           template for a phase's runnable exit criterion
.claude/workflows/run-phase.js   unattended phase runner (both profiles)
```

The scripts are language-agnostic: set `CHECKS`, `GATE_CHECKS` and the
determinism command in `scripts/method.conf` (defaults are for Rust/cargo).
