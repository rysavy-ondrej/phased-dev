# Implementation plan

Derived from `SPEC.md`. The project passes through three modes — **prototype**,
**harnessing**, **production** (`CLAUDE.md` → *Modes*). Each mode holds phases,
numbered 1..N across the whole plan; a phase may be split into subphases A, B,
C. Every phase ends with a runnable program, a comprehensive test
(`scripts/gate.sh <n>`) and a push.

Task markers: ☐ not started · ◐ committed, not yet verified · ☑ verified.
Each task is one commit; only a task's own commits change its marker.

Every task is **small**: it touches one module or one contract and has one
observable outcome (`plan` skill, *Size rule*). Boundaries come first.

## Mode allocation

Proposed by the `plan` skill, confirmed by the owner. Every spec item appears
once per mode it is touched in.

| Spec item | Prototype (demonstrate) | Harnessing (make trustworthy) | Production (complete) |
| --- | --- | --- | --- |
| {{§6.1 parse input format}} | typical files only | truncated/malformed files, conformance vs authority | fuzz target, large-file performance |
| {{§5 CLI}} | the flags the demo needs | full validation, exit codes | help text, shell completion |
| {{secondary feature X}} | — | — | full |

Prototype exit: {{the end-to-end demonstration that ends the prototype — a
command on sample data and what it shows}}.

---

# Prototype

Detailed now. The later modes are outlined and detailed when the prototype has
shown what they need.

## Phase 1 — {{Title}}

Goal: {{one sentence}}.

**Phase exit:** {{a command and what it must produce. Graded by
`scripts/phase1-gate.sh`.}}

### Preparation

Written by the `prepare-phase` skill before any code; its absence means the
phase is not ready.

Prepared: {{date}}

| # | Task | Depends on | Implementation group | Why here |
| --- | --- | --- | --- | --- |
| 1 | T1.1 | — | G1 | builds the contracts everything else uses (walking skeleton) |

**Questions answered for this phase:** Q-… ; none open.
**Fixtures and data:** {{which exist, which the phase must create}}.
**Traps and findings:** {{found once, so the run does not rediscover them}}.

### Subphase 1A — Boundaries (walking skeleton)

Every contract from `SPEC.md` §4 as code, each with the simplest
implementation that lets data flow end to end, plus the contract tests.

- ☐ **T1.1 {{Title}}.** {{Requirement, precise enough that a verifier can quote
  it and say met / partly / unmet.}} *Small test:* {{the demonstration test,
  naming its target.}}

### Subphase 1B — {{first module filled in behind its contract}}

- ☐ **T1.2 {{Title}}.** …

---

# Harnessing

Outline — detailed after the prototype exit. Input: the *Harnessing* column
above, the `mode: harnessing` entries in `FEATURES.md`, the prototype backlog.

## Phase 3 — {{Title}}

- {{scope in a line or two; tasks written when the phase is planned in detail}}

---

# Production

Outline — detailed after harnessing.

## Phase 5 — {{Title}}

- {{…}}
