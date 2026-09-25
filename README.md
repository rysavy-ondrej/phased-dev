# phased-dev

A development method for software built with Claude Code agents — from the
owner's concept notes, through a specification and an implementation plan, to
phased implementation and a finished product. Packaged as a Claude Code plugin.

Extracted from the maestro-enjoy project, where every rule was added after a
measured failure (`plugins/phased-dev/skills/method/references/lessons.md`).

## Install

```bash
claude plugin marketplace add rysavy-ondrej/phased-dev
claude plugin install phased-dev@phased-dev
```

Or, inside Claude Code: `/plugin marketplace add rysavy-ondrej/phased-dev`, then
`/plugin install phased-dev@phased-dev`. While the repository is private, the
machine needs git access to it (e.g. `gh auth login`).

To work on the plugin itself, clone it and add the local checkout instead:
`claude plugin marketplace add ./phased-dev`.

## The flow

1. **Concept** — the owner writes `docs/CONCEPT.md` in their own words.
2. **Spec** — derived from the concept: architecture, languages, frameworks,
   allowed libraries, interfaces, behaviour. Open questions are answered by the
   owner before it is confirmed.
3. **Plan** — proposes which parts of the spec are built in which **mode**, then
   phases 1..N with subphases A, B, C.
4. **Implementation**, phase by phase: prepare (fix task order, answer questions)
   → implement (per task: small tests, **commit**, independent verifier with
   suggested repairs, ☑) → comprehensive tests, review, triage → **push**.

### Three modes, in order

| Mode | Purpose |
| --- | --- |
| **prototype** | demonstrate the functionality end to end, quickly and cheaply — no harness, no edge cases |
| **harnessing** | make the prototype trustworthy: tests, conformance, edge cases, error handling |
| **production** | complete the product: remaining features, robustness, performance, packaging, docs |

The mode sets test depth, verification strength and review size. It never
relaxes honesty of the output, tests that can fail, commit per task, or
"failure is a stop".

## Skills

| Skill | When |
| --- | --- |
| `/phased-dev:method` | overview; what comes next |
| `/phased-dev:start` | begin from concept notes: scaffold, find gaps, ask |
| `/phased-dev:specify` | concept → `docs/SPEC.md`, `CLAUDE.md` |
| `/phased-dev:plan` | spec → mode allocation, phases, tasks |
| `/phased-dev:prepare-phase` | before each phase: order, groups, questions answered, gate script |
| `/phased-dev:implement` | implement a phase: task → commit → verify → ☑, progress after each |
| `/phased-dev:gate` | finish a phase: comprehensive tests, review, triage, push |
| `/phased-dev:status` | where the implementation is, open questions, next step |
| `/phased-dev:question` | record or answer a question |
| `/phased-dev:feature` | record a new requirement → later phase, later mode, or future cycle |
| `/phased-dev:resume` | continue after a usage/rate limit or an interruption |
| `/phased-dev:registers` | which document a gap belongs in |

## Progress, pause and resume

All state is in git. Each task in the plan is ☐ (not started), ◐ (committed, not
yet verified) or ☑ (verified). `scripts/progress.sh` prints the picture and the
next step; `scripts/progress.sh questions` lists the open questions. When a usage
or rate limit is hit, the run pauses cleanly and records it in
`docs/STATUS.md`; `resume` verifies any ◐ task first, then continues.

## What a project gets

`plugins/phased-dev/scripts/scaffold.sh <dir>` (run by `start`) installs, never
overwriting an existing file:

```
CLAUDE.md                        the rules every agent reads
docs/CONCEPT.md                  template for the owner's concept notes
docs/SPEC.md                     architecture, technology, allowed libraries, behaviour
docs/IMPLEMENTATION_PLAN.md      mode allocation, phases, subphases, tasks
docs/QUESTIONS.md FEATURES.md    questions and answers; new features with dispositions
docs/STATUS.md BACKLOG.md DIVERGENCES.md UNVALIDATED.md PROVENANCE.md TEST_DATA.md
scripts/method.conf              the project's check commands
scripts/task-audit.sh            per-task audit (commit form, markers, green)
scripts/gate.sh                  per-phase mechanical gate
scripts/progress.sh              progress, open questions, next step
scripts/phase1-gate.sh           template for a phase's runnable exit criterion
.claude/workflows/run-phase.js   unattended phase runner
```

The scripts are language-agnostic: set `CHECKS`, `GATE_CHECKS` and the
determinism command in `scripts/method.conf` (defaults are for Rust/cargo).
