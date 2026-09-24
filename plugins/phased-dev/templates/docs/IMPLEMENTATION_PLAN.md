# Implementation plan

Tasks are executed **in order**, committed straight onto `main`. Each
{{UNIT}} is one commit, green, with its small-scale test passing. Nothing is
pushed mid-phase. Each phase ends with a runnable program and a full-scale test
of its exit criterion (`scripts/gate.sh <n>`); `main` is pushed only after that
passes. A task that cannot be completed stops the run and is reported.

Legend: ☐ not started · ☑ done. A box is ticked by the commit that does the work,
and by no other.

---

## Phase 0 — Skeleton

Goal: {{the shell of the final program — its interface, configuration and error
handling — so later phases only add capability, never restructure.}}

### Readiness, checked {{date}} before the run

Found once, so the run does not rediscover it: fixtures that exist for this
phase, dependencies it needs, owner decisions it is waiting on, surface that
already exists.

1. {{finding}}

<!-- profile:prototype -->
### Batches

| Batch | Tasks | Shared context | Verified together by | Size |
| --- | --- | --- | --- | --- |
| B0.1 | T0.1, T0.2, T0.3 | {{module/files}} | {{one command or test file}} | S/M/L |

<!-- /profile:prototype -->
- ☐ **T0.1 {{Title}}.** {{Requirement, precise enough that a verifier can quote
  it and say met / unmet.}} *Small-scale test:* {{the test that would fail if the
  behaviour were broken, naming the test target.}}

**Phase exit:** {{an observable, runnable criterion — a command and what it must
print — not a feeling.}} Checked by `scripts/phase0-gate.sh`.

---

## Settled decisions

| # | Decision | Reason |
| --- | --- | --- |
| D1 | **{{decision}}** | {{why; the measurement behind it; who ruled and when; what would reopen it}} |
