# Concept

Written before any specification. It answers *why* and *what for*; the *what
exactly* is `CLAUDE.md` (invariants) and `IMPLEMENTATION_PLAN.md` (tasks).

## Purpose

{{One paragraph: what the program does and who consumes its output.}}

## The question
<!-- profile:prototype -->
{{The single question this prototype exists to answer, phrased so that it has a
yes/no or a number as its answer. E.g. "Can a from-scratch decoder reproduce the
reference's records on the 20-capture corpus at ≥10x its throughput?"}}

**Answered when:** {{the observable result that settles it — the final phase's
exit criterion.}}

Everything built serves this question. Anything that does not is parked in
`OUT_OF_SCOPE.md`.
<!-- /profile:prototype -->
<!-- profile:production -->
{{The outcome that makes this release worth shipping, stated so it can be
checked.}}
<!-- /profile:production -->

## The authority

{{What is normative: reference implementation, standard, golden outputs. Where
its copy lives. Which version produced any goldens.}}

## Priorities when they conflict

1. {{prime directive}}
2. Never crash, never break the output contract, never lie in the output.
3. Functionality and simplicity.
4. {{speed / footprint / ...}}

## In scope

- {{capability}}

## Out of scope

- {{capability}} — {{why}}. (Prototype: each has an `OOS-n` entry in
  `OUT_OF_SCOPE.md`.)

## Constraints

- Platform: {{target; what must stay reachable}}
- Dependencies: {{policy}}
- Data: {{what test data exists, whether it can be committed}}

## Open questions for the owner

Numbered; each is closed by a dated ruling copied into the plan's *Settled
decisions*.

1. {{question}}
