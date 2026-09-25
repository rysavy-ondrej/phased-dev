---
name: plan
description: Step 3 of the phased-dev method — turn the confirmed spec into docs/IMPLEMENTATION_PLAN.md: propose which parts of the spec are built in which project mode (prototype, harnessing, production), then phases 1..N with subphases, tasks with small tests and runnable phase exit criteria. The prototype is planned in detail and kept minimal; later modes are outlined. Use after specify, when moving to the next mode, or when a plan needs re-cutting.
---

# Plan

Read `CLAUDE.md` (*Modes*), `docs/SPEC.md` (confirmed), `docs/CONCEPT.md` (the
prototype milestone), `docs/FEATURES.md`, `docs/TEST_DATA.md`.

## 1. Propose the mode allocation

For every spec item — each component, interface, behaviour rule, quality target —
decide what each mode does with it, and fill the *Mode allocation* table:

- **Prototype: the least that demonstrates the functionality end to end.** The
  main path on expected input, through every module boundary once. Ask of each item: *is the
  demonstration impossible without it?* If not, it is not prototype work. No
  edge cases, no harness, no error polish, no secondary features, no
  performance work. The only robustness is honesty: unhandled input is refused
  or visibly skipped.
- **Harnessing: what makes the prototype trustworthy.** Tests for every behaviour
  rule, conformance with the authority on the full data, edge and malformed
  input, error handling, gate scripts, removal of prototype shortcuts.
- **Production: what completes the product.** Remaining features, robustness
  against hostile input, performance targets, packaging, CI, portability,
  user documentation.

State the **prototype exit**: one demonstration (a command on sample data and
what it shows) that ends the prototype. The sample data is named: a set from
`docs/DATA.md`, or a small synthetic demo set the first phase generates
(`test-data`, Part 2).

**Show the allocation to the owner and get it confirmed** before writing
phases — it is the decision that sets the cost of the whole project. Record
disagreements as answered questions.

## 2. Phases and subphases

- Phases are numbered **1..N across the whole plan**, grouped under the headings
  `# Prototype`, `# Harnessing`, `# Production` (the scripts read the mode from
  them).
- Each phase ends with a **runnable program** and adds capability without
  restructuring what came before; boundaries and contracts are built before anything hangs off them.
- Split a phase into **subphases A, B, C** (`### Subphase 2A — …`) when it is wider
  than ~6–8 tasks or mixes a foundation with what is built on it. Subphases get a
  checkpoint gate run; the push waits for the whole phase.
- Every phase has a **Goal** and a **Phase exit**: a command and what it must
  produce, on real data, graded by `scripts/phase<N>-gate.sh`. Prototype exits
  are demonstrations; harnessing exits are conformance results; production exits
  include the quality targets.

**Detail only the prototype now.** Harnessing and production phases are an
outline (title and a line or two of scope): what the prototype teaches changes
them, and detail written now would be rewritten. Plan the next mode in detail
when the previous one exits (see `method/references/modes.md`).

A prototype is typically 1–3 phases. More suggests the allocation put
harnessing work in the prototype — re-check it.

## 3. Boundaries first

The first prototype phase (or subphase 1A) **builds the boundaries**: every
contract from the spec as code, each with the simplest implementation that lets
data flow end to end (a walking skeleton), and the contract tests. Every later
task then fills one module behind a boundary that already exists. A plan whose
first tasks build module internals before the interfaces exist is out of order.

## 4. Tasks — small by rule


`- ☐ **T<phase>.<n> Title.** Requirement.` Ids are unique within a phase
(subphases do not restart numbering). Each requirement is precise enough to quote
and judge met / partly / unmet, and names its **small test** at the depth of its
mode: a demonstration test in prototype, every named behaviour in harnessing and
production. Name the existing fixtures it must use.

**Size rule.** A task:
- touches **one module or one contract** (plus its tests);
- has **one observable outcome** its small test demonstrates;
- is small enough to implement, test and verify in one sitting — as a rough
  guide, a few hundred changed lines at most.

A task that breaks any of these is **split** — along the module boundary, or into
"contract / first implementation / next behaviour" — before the plan is
confirmed. A task that changes a contract says so in its title and needs an
answered question.

Do **not** fix task order or groups here — that is `prepare-phase`, done just
before each phase, when the code it builds on exists.

## 5. Deferred work

Everything the prototype deliberately skips that a later mode must do is a
`kind: hardening` entry in `docs/FEATURES.md` with `Disposition: mode:
harnessing` or `mode: production` — or is covered by the allocation table's later
columns. Nothing skipped is left unrecorded.

## 6. Gate scripts and status

Create `scripts/phase<N>-gate.sh` for each detailed phase from
`scripts/phase1-gate.sh`'s template (or leave it to that phase's preparation).
Set `docs/STATUS.md` → mode `prototype`, and list the phases. Then
`prepare-phase` for phase 1.
