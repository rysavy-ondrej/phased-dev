# {{PROJECT}} — agent context

Read this before touching code. It is injected into every agent, so it is the one
place a rule lives; prompts and skills name a rule, they do not restate it.

## What this project is

{{WHAT_IT_IS — two or three sentences from the concept: what it does, its inputs
and outputs, who consumes the output.}}

**What wins when they conflict:** 1. **{{PRIME}}** (the prime directive below) ·
2. never crash on input, never break the output contract, never lie in the
output · 3. functionality and simplicity · 4. speed.

That is **proportionate effort**, not a preference for slow code: when the
efficient shape is the natural one, write it. Not warranted is elaborate
machinery or a new failure mode for a gain nobody measured. **Performance is
measured, not asserted:** a choice that depends on speed or memory is decided by
a measurement (`docs/MEASUREMENTS.md`, `measure` skill), and every performance
claim cites its `M-n`.

## The prime directive: {{PRIME}}

{{AUTHORITY — what decides correctness: a reference implementation, a standard,
golden outputs, or the concept itself; where its read-only copy lives.}}

When this file, the spec or your judgement disagrees with the authority, **the
authority wins** — raise a question (`docs/QUESTIONS.md`); never silently
"improve" the behaviour.

**Invariants** — the rules a sensible design gets wrong by default, each citing
its source (the full behaviour is `docs/SPEC.md` §4):

1. {{INVARIANT — precise enough to test; cite the source.}}

## Technology

From `docs/SPEC.md` §3, which is authoritative: {{language · frameworks · target
platforms}}.

- **Libraries:** only those in `docs/SPEC.md` → *Allowed libraries*. Another one
  is a question for the owner, answered before it is used.
- **Tools** on the development machine: `TOOLS` in `scripts/method.conf`, checked
  by `scripts/check-env.sh`. Nothing is installed or configured without the
  owner's consent (`dev-env`, `git-setup`).

## Design rules

The spec is detailed enough that a task fills in a box whose edges are fixed.

1. **Boundaries first.** Components and the contracts between them are built
   first — every interface, wired end to end with the simplest implementation (a
   walking skeleton). Later tasks fill one component at a time.
2. **Every boundary has a contract**, as code in the project's language and in
   `docs/SPEC.md` → *Components and contracts*: inputs, outputs, errors,
   pre/postconditions, ownership, an example, a contract test.
3. **Contracts change deliberately.** Changing an interface others depend on, or
   using a pattern the spec does not name, is a question first; the spec changes
   in the same commit.
4. **Named patterns.** Each component uses the pattern its spec entry names
   (Strategy, Adapter, Pipeline, Factory …).
5. **Keep parts simple.** One responsibility per component, class and function,
   within the spec's *Complexity budget*; past it, split along a responsibility —
   never add a flag.
6. **Small tasks.** One component or contract, one observable outcome. Too big →
   split in the plan, not implemented large.

| Component | Location | Contract | Pattern | Contains the change of … |
| --- | --- | --- | --- | --- |
| {{component}} | {{path}} | {{Interface}} | {{pattern}} | {{what varies behind it}} |

Adding behind one boundary never requires touching another; if it does, fix the
boundaries (via a question) rather than special-casing.

## The output contract

{{Where results go and what else may appear there, e.g. "stdout carries records
and nothing else; diagnostics go to stderr". Which modes are exempt.}}

## Code

- **Never crash on input:** parsers return errors; no unchecked indexing.
- **Never lie in the output:** input that is not handled (yet) is refused or
  skipped visibly — never a plausible wrong result.
- {{Language rules: error types, no unwrap on input-derived data, unsafe policy,
  hot-path allocation.}}
- Every commit leaves the `CHECKS` in `scripts/method.conf` green, the complexity
  lint included.

## Modes

The project passes through three modes in order; `docs/IMPLEMENTATION_PLAN.md` →
*Mode allocation* says what each builds; `docs/STATUS.md` holds the current one.

| | **prototype** | **harnessing** | **production** |
| --- | --- | --- | --- |
| Goal | demonstrate end to end, quickly and cheaply | make it trustworthy | complete the product |
| Builds | the main path through every boundary, on expected input | test harness, conformance, edge cases, errors, shortcut removal | remaining features, robustness, performance, packaging, CI, docs |
| Small tests per task | one demonstration test | every named behaviour, incl. edge and malformed input | + fuzz targets for untrusted input |
| Verifier | works? does the demo test exercise it? | every new test proven to fail (mutation) | same + hostile input |
| Verification unit · repair rounds | per group · 1 | per task · 3 | per task · 3 |
| Phase review | one short combined | tests + conformance | full panel + critic |

**Prototype means cheap, not dishonest.** Unhandled input is refused or visibly
skipped; everything skipped is a `kind: hardening` entry in `docs/FEATURES.md`
for a later mode. Do not add harness, edge cases or polish to a prototype task.

**Never relaxed:** the prime directive · never lie in the output · a test that
exists can fail · one commit per task · failure is a stop.

## Testing

| Tier | When | What |
| --- | --- | --- |
| **Small** | every task, before its commit | the task's tests at its mode's depth, literal fixtures, a smoke run of the real program |
| **Comprehensive** | every phase, before its push | `scripts/gate.sh <n>`, the phase exit criterion on real data, conformance once it exists |

- **Tests that cannot fail** are the most common defect: a test observes
  something *near* the behaviour it names. A fixture is **literal data, never the
  constant under test**; every table of magic numbers has a test pinning each
  value to a literal with its citation. For every test: *could it pass with the
  behaviour broken?* Prove it — break the code, run that test, watch it fail,
  revert. Prefer tests that run the real program.
- **Test data:** read `docs/DATA.md`, `docs/PROVENANCE.md` and
  `docs/TEST_DATA.md` before building a fixture. Synthetic data comes from seeded
  generators validated by a reader that is not ours; an expected result never
  comes from the code under test (`test-data`).
- Compare with the authority the way it can be compared (semantically when its
  output is not byte-reproducible); our own output is byte-identical across runs.
  Accepted differences: `docs/DIVERGENCES.md`. Unchecked leaves (nothing reads
  their output): `docs/UNVALIDATED.md`.

## Working agreement

- **Prepared first.** A phase starts only with `Prepared: <date>` in the plan:
  task order fixed, groups set, questions affecting it answered, environment
  checked, gate script written (`prepare-phase`).
- **One task, one commit.** Tasks run in the prepared order. The implementer
  writes the task and its small tests, marks it ◐, commits `T2.3: <what>` with the
  trailer, and runs `scripts/task-audit.sh T2.3`. An independent read-only
  **verifier** reports problems, each with a suggested repair; repairs are further
  `T2.3:` commits, rechecked against that list only; on a pass the task is marked
  ☑ in `T2.3: verified`. Tasks of one implementation group may be implemented
  before the group is verified; the next group starts when the previous one is ☑.
  Only a task's own commits change its marker (☐ to do · ◐ committed · ☑ verified).
- **The push is the phase.** `git push` once per phase, after `scripts/gate.sh
  <n>` passes and the phase report `docs/reports/<PROJECT>_phase_<n>.md` is
  written (what was done, how to try it, specified vs implemented — every example
  actually run). Subphases get a checkpoint gate, no push. Pushing a failed gate
  only when someone needs the work, with `docs/STATUS.md` saying so. `main` moves
  forward only; phase-level commits use `P<n>: `.
- **Questions** go to `docs/QUESTIONS.md` at once. Blocking (changes what the task
  builds): stop and ask. Non-blocking: continue on a stated assumption. All are
  answered before the next phase is prepared.
- **New features** go to `docs/FEATURES.md`, never built inside a task; the owner
  gives each a disposition at the gate (later phase, later mode, future cycle,
  rejected).
- **Failure is a stop.** Report what was attempted, the exact output, the likely
  cause, the decision needed. Never commit red, weaken a test, call a real diff a
  divergence, skip ahead or silently narrow a task.
- **Progress and pauses.** One progress line after every task. All state is in git
  (markers, commits), so at a usage limit: finish or cleanly abandon the step,
  record the pause and reset time in `docs/STATUS.md` → *Current run*, stop — no
  retry loop. `resume` verifies ◐ tasks first, then continues.
- **Tokens.** Mechanical checks are scripts (`task-audit.sh`, `gate.sh`,
  `progress.sh`, `check-env.sh`); never re-derive them. Targeted tests while
  working, the full suite once per task, determinism only at the gate.
  Observations are triaged or not asked for. A dead agent verified nothing.

## Working with caveman

The `caveman` plugin compresses **chat** only; files, commits and docs stay in
normal prose. Its skills may shape *how* a step is done; this file defines *what*
is required:

1. Commit subjects stay `T2.3: …` plus the trailer, whatever a commit skill says.
2. Never compress `CLAUDE.md`, `docs/**`, the plan, spec or registers — the
   scripts parse them.
3. Done = the task's requirement and small test at its mode's depth, proven by the
   verifier — not a smaller proof set (`verify-and-stop`, `lean-build`).
4. Verifier and gate reviews use phased-dev's prompts; caveman reviewers never
   replace them. `cavecrew-investigator` is fine; `cavecrew-builder` only inside
   the current task, which the main session tests, commits and audits.
5. The per-task progress line is required output.
6. Decisions put to the owner are written in full sentences (Auto-Clarity).

## Documents

| File | Holds |
| --- | --- |
| `docs/CONCEPT.md` | the owner's idea — written by the owner |
| `docs/SPEC.md` | the design, level by level, and its decision log |
| `docs/IMPLEMENTATION_PLAN.md` | mode allocation, phases, subphases, tasks |
| `docs/STATUS.md` | where the project is; the current run and pauses |
| `docs/QUESTIONS.md` · `docs/FEATURES.md` | questions and answers · new features and their dispositions |
| `docs/BACKLOG.md` | defects in what was built, not blocking |
| `docs/DIVERGENCES.md` · `docs/UNVALIDATED.md` | deliberate differences from the authority · unchecked leaves |
| `docs/DATA.md` · `docs/PROVENANCE.md` · `docs/TEST_DATA.md` | test data catalog · its origin · what is missing |
| `docs/MEASUREMENTS.md` | performance decisions and their reports |
| `docs/ENVIRONMENT.md` | machines, tools, versions; how to set up another |
| `docs/reports/<PROJECT>_phase_<n>.md` | per phase: what was done, how to try it |

Prose that describes behaviour is checked against the behaviour, like code.

## Conventions

- {{formatter and lint configuration; package and binary names}}
