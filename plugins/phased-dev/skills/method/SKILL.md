---
name: method
description: Overview of the phased-dev method — from the owner's concept notes through the specification and the implementation plan to phased implementation in three project modes (prototype, harnessing, production), and which phased-dev skill to use at each step. Use when starting a project with this method, when unsure what comes next, or when asked how the method works.
---

# The phased-dev method

Software built with agents, from a human's concept notes to a product, in a way
that stays honest and affordable: one constitution every agent reads
(`CLAUDE.md`), a spec derived from the concept, a plan of phases with runnable
exit criteria, one commit per task, an independent verifier, mechanical checks
as scripts, all state in git, and registers that keep every open question and
new idea visible.

Extracted from maestro-enjoy, where every rule was bought by a measured failure —
`references/lessons.md` has the evidence. Read it before relaxing a rule.

## The flow

```
CONCEPT.md ──start──▶ questions ──specify──▶ SPEC.md ──plan──▶ IMPLEMENTATION_PLAN.md
 (owner)                (owner answers)       (owner confirms)   (mode allocation, phases)
                                                                          │
      ┌──────────────────── for each phase 1..N ───────────────────────────┘
      ▼
 prepare-phase ──▶ implement (task → commit → verify → ☑, per task) ──▶ gate ──▶ push
      ▲                 │  questions → question    new features → feature
      │                 │  rate limit → pause ─── resume ──┘
      └── next phase ◀──┘                         status: anytime
```

| Step | Skill | Input → output | Done when |
| --- | --- | --- | --- |
| 1 | `start` | owner's `docs/CONCEPT.md` → scaffolded repo, gaps as `Q-n` questions | the owner has answered the concept questions |
| 2 | `specify` | concept + answers → `docs/SPEC.md` (architecture, languages, frameworks, allowed libraries, interfaces, behaviour), `CLAUDE.md` filled | every `spec` question answered; owner confirms the spec |
| 3 | `plan` | spec → `docs/IMPLEMENTATION_PLAN.md`: **mode allocation**, phases 1..N, subphases, tasks | owner confirms which work goes in which mode |
| 4 | `prepare-phase` | a phase → fixed task order, dependencies, groups, answered questions, gate script | `Prepared: <date>` in the plan |
| 5 | `implement` | prepared phase → one commit per task, each verified (☐ → ◐ → ☑) | every task ☑ |
| 6 | `gate` | finished phase → comprehensive tests, review, triage, STATUS, **push** | gate passes, push done |
| any | `status` | → where the implementation is, open questions, what is next | |
| any | `question` | a question that came up → `Q-n` | answered before the next phase is prepared |
| any | `feature` | a new requirement that came up → `F-n` with a disposition | owner rules at triage: later phase, future cycle, or rejected |
| any | `resume` | after a pause (usage/rate limit, interruption) → continues from git state | |
| any | `registers` | which document a gap belongs in | |

Steps 4–6 repeat for each phase.

## The three modes are stages of the project

The `plan` skill allocates each part of the spec to the mode it is built in:

1. **Prototype** — demonstrate the functionality end to end, **quickly and
   cheaply**. The main path on expected input, no harness, no edge cases, no
   polish. Unhandled input is refused or visibly skipped, never turned into a
   wrong answer, and every skipped hardening item is recorded for later.
2. **Harnessing** — make the prototype trustworthy: test harness, conformance
   with the authority, edge cases, error handling, shortcuts removed.
3. **Production** — complete the product: the remaining features, robustness,
   performance, packaging, CI, documentation.

The mode sets test depth, verification strength and review size
(`references/modes.md`). It never relaxes: honesty of the output, tests that can
fail, one commit per task, failure is a stop.

## Rules that hold in every step

- The owner writes the concept and answers questions; agents derive, propose and
  ask. Owner decisions are dated.
- `CLAUDE.md` is the single home of a rule; skills and prompts name it.
- The authority wins over prose and judgement.
- Commit after every task, push after every phase.
- Anything mechanical is a script (`task-audit.sh`, `gate.sh`, `progress.sh`).
- All state is in git, so any step can pause and resume.
- Failure is a stop: report the exact output and the likely cause.
