---
name: method
description: Overview of the phased-dev method: concept → interactive spec → plan → phases in three project modes (prototype, harnessing, production), and which skill comes next. Use when starting with the method, unsure what is next, or asked how it works.
---

# The phased-dev method

Software built with agents, from the owner's concept notes to a product, kept
honest and affordable: one constitution every agent reads (the project's
`CLAUDE.md`, from `templates/CLAUDE.md`), a spec designed with the owner, a plan
of phases with runnable exit criteria, one commit per task, an independent
verifier, mechanical checks as scripts, all state in git, and registers that keep
open questions and new ideas visible. Every rule was bought by a measured failure
in the maestro-enjoy project — `references/lessons.md`; read it before relaxing
one.

## The flow

```
CONCEPT.md ─start─▶ specify ─────────────────────────────▶ SPEC.md ─plan─▶ IMPLEMENTATION_PLAN.md
 (owner; may        level 0 scope → 1 architecture         (every level    (mode allocation,
  be abstract)      → 2 technology → 3 components          confirmed)       phases 1..N)
                    → 4 cross-cutting                                              │
                    agent proposes options, owner decides                          │
                                                                                   │
      ┌──────────────────────────── for each phase ────────────────────────────────┘
      ▼
 prepare-phase ──▶ implement (task → commit → verify → ☑, per task) ──▶ gate ──▶ report, push
      ▲                 │  questions → question    new features → feature
      │                 │  usage limit → pause ─── resume ──┘
      └── next phase ◀──┘                         status: anytime
```

| Step | Skill | Result | Done when |
| --- | --- | --- | --- |
| 1 | `start` (runs `git-setup`) | repo scaffolded, git/gh ready, what the concept decides | handed to `specify` |
| 2 | `specify` (runs `dev-env` after level 2) | `docs/SPEC.md`, level by level; toolchain installed | every level confirmed by the owner |
| 3 | `plan` | mode allocation, phases, subphases, tasks | owner confirms the allocation |
| 4 | `prepare-phase` | order, groups, answered questions, environment, gate script | `Prepared: <date>` |
| 5 | `implement` | one commit per task, each verified (☐ → ◐ → ☑) | every task ☑ |
| 6 | `gate` | tests, review, triage, phase report, push | gate passes, report written |
| any | `status` | where things stand, open questions, next step | |
| any | `question` · `feature` | `Q-n` · `F-n` (later phase, later mode, future cycle, rejected) | owner answered · disposed |
| any | `test-data` · `measure` | data catalog and synthetic data · measured decision `M-n` | |
| any | `git-setup` · `dev-env` | git/GitHub · toolchain checked, installed with consent | `scripts/check-env.sh` clean |
| any | `resume` · `registers` | continue from git · which document a gap belongs in | |

Steps 4–6 repeat per phase. When the last phase of a mode passes, `plan` details
the next mode (`references/modes.md`).

## Modes are stages of the project

**Prototype** demonstrates the functionality end to end, quickly and cheaply;
**harnessing** makes it trustworthy; **production** completes it. The mode sets
test depth, verification and review size (the *Modes* table in the project's
`CLAUDE.md`), never honesty of the output, tests that can fail, commit per task,
or failure is a stop.

## Principles

- The owner writes the concept and makes the decisions; the agent designs,
  proposes options with trade-offs, and asks. Only obvious choices are the
  agent's, logged for veto.
- Big becomes small: components with one responsibility, contracts first, tasks
  of one component with one outcome, a complexity budget.
- The authority wins over prose and judgement; performance is measured.
- Mechanical checks are scripts; all state is in git; failure is a stop.
- Installed with caveman: chat is terse, files are not; where they meet, the
  project `CLAUDE.md` → *Working with caveman* rules (`references/caveman.md`).
