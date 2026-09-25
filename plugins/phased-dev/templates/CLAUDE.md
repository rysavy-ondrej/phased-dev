# {{PROJECT}} — agent context

Read this file before touching any code. It records the rules that are easy to
get wrong and expensive to discover late. It is injected into every agent, so it
is the one place a rule lives; prompts name a rule, they do not restate it.

| Document | Role | Written by |
| --- | --- | --- |
| `docs/CONCEPT.md` | why the project exists, what it must do — the starting point | the owner (human) |
| `docs/SPEC.md` | how: architecture, technology, allowed libraries, component contracts, patterns, decision log | designed by the agent level by level; every major decision the owner's |
| `docs/IMPLEMENTATION_PLAN.md` | phases, subphases, ordered tasks, modes, exit criteria | derived from the spec |
| this file | the rules every agent follows | derived from all three |

## What this project is

{{WHAT_IT_IS — two or three sentences from the concept: what it does, its
inputs and outputs, who consumes the output.}}

### What wins when they conflict

1. **{{PRIME}}** — the prime directive below. Never traded for anything.
2. **Never crash on input, never break the output contract, never lie in the output.**
3. **Functionality and simplicity.** Obviously correct beats clever.
4. **Speed.**

**Performance is measured, not asserted.** A choice that depends on speed or
memory is decided by a measurement (`docs/MEASUREMENTS.md`, `measure` skill),
and every performance claim — in the spec, a commit, a comment — cites its
`M-n`.

This is about **proportionate effort**, not about preferring slow code. When the
efficient shape is the natural one to write, it is simply the right code. What is
not warranted is *disproportionate* effort — elaborate machinery, new failure
modes, new invariants — for a gain nobody has measured a need for. Write the
plain version, record the choice and its measured cost in the spec's
*Decision log*, and leave optimisation to a production phase with a benchmark.

## The prime directive: {{PRIME}}

{{AUTHORITY — what is normative when opinions differ: a reference
implementation, a standard, golden outputs, or the concept itself. Where its copy
lives (read-only).}}

When this document, the spec, or your own judgement disagrees with the
authority, **the authority wins** — raise a question (`docs/QUESTIONS.md`), do not
silently "improve" the behaviour.

### Invariants

The rules a sensible design gets **wrong by default**, each with its source. The
full specification is `docs/SPEC.md`; this list is the part every agent must hold
in mind.

1. {{INVARIANT — precise enough to test; cite the source.}}

## Technology constraints

Summarised from `docs/SPEC.md`, which is authoritative:

- Languages: {{…}} · Frameworks: {{…}} · Target platforms: {{…}}
- **Libraries: only those listed in `docs/SPEC.md` → *Allowed libraries*.** Adding
  one is a question for the owner (`docs/QUESTIONS.md`), answered before the
  library is used — never a decision an implementer takes alone.

## Design rules

The spec (`docs/SPEC.md` → *Components and contracts*) is detailed enough that
implementing a task is filling in a well-defined box, not designing one.

1. **Boundaries first.** The modules and the boundaries between them are defined
   before the code inside them, and built first: the earliest prototype tasks
   create every interface and wire them end to end with the simplest possible
   implementations (a walking skeleton). Later tasks fill one module at a time.
2. **Every boundary has a contract**, written as code in the project's language
   (trait, interface, abstract class, typed signature) *and* stated in the spec:
   inputs, outputs, errors, pre- and postconditions, ownership/lifetime,
   invariants, an example. A contract test checks each implementation against it.
3. **A contract is changed deliberately, never in passing.** Changing an interface
   another module depends on is a question for the owner (`docs/QUESTIONS.md`),
   answered before the change, and the spec is updated in the same commit.
4. **Named design patterns.** Each module states the pattern it follows and why
   (each component's *Pattern* in the spec) — e.g. Strategy for interchangeable algorithms,
   Adapter behind an external source, Pipeline for staged processing, Factory
   where the concrete type is chosen by configuration. Use the pattern the spec
   names; a pattern the spec does not name is a question, not an improvisation.
5. **Keep every part simple.** One responsibility per module, class and function.
   The limits in the spec's *Complexity budget* (function length, nesting,
   parameters, dependencies per module) apply to all code; when a part grows past
   them, split it along a responsibility — do not add a flag.
6. **Small tasks.** A task touches one module or one contract and has one
   observable outcome. A task that does not fit is split in the plan, not
   implemented large.

| Module | Location | Contract (interface) | Pattern | Contains the change of... |
| --- | --- | --- | --- | --- |
| {{module}} | {{path}} | {{Interface name}} | {{pattern}} | {{what varies behind it}} |

Adding behind one boundary never requires touching another. If it does, the
split is wrong — fix the boundaries (via a question) rather than special-casing.

## The output contract

{{Where results go and what else may appear there, e.g. "stdout carries records
and nothing else; diagnostics go to stderr". Which modes are exempt.}}

## Modes

The project passes through three modes, in order. The plan
(`docs/IMPLEMENTATION_PLAN.md` → *Mode allocation*) says which parts of the spec
are built in which mode; the current mode is in `docs/STATUS.md`.

| | **1. prototype** | **2. harnessing** | **3. production** |
| --- | --- | --- | --- |
| Goal | **demonstrate the functionality end to end, quickly and cheaply** | make the prototype trustworthy | complete the product |
| Builds | the main path from input to output through every module boundary, on the expected input | the test harness, conformance with the authority, edge cases, error handling, removal of prototype shortcuts | the remaining features, robustness, performance, packaging, CI, portability, user documentation |
| Does not build | edge cases, harnesses, error polish, secondary features | new features | — |
| Small tests per task | one demonstration test: the task's behaviour on typical input | every behaviour the task names, including edge and malformed cases | as harnessing, plus fuzz targets for untrusted input |
| Verifier | checks the task works and its demonstration test actually exercises it | proves every new test can fail (mutation) | proves every new test can fail (mutation) |
| Repair rounds | 1 | 3 | 3 |
| Phase review | one short combined review | tests + conformance lenses | full panel + completeness critic |

**Prototype means cheap, not dishonest.** Edge cases are not solved, but input
the prototype does not handle must not produce a plausible wrong result: the
simplest honest behaviour — refuse, or skip and count on the diagnostic channel
— is enough. Everything skipped is one `kind: hardening` line in
`docs/FEATURES.md` with `Disposition: mode: harnessing` (or production); the
harnessing phases are planned from that list.

**Never relaxed in any mode:** the prime directive; never lying in the output; a
test that exists must be able to fail; one commit per task; failure is a stop.

## Non-negotiables for the code itself

- **Never crash on input.** Parsers return errors; indexing without a length
  check is a bug.
- **Never lie in the output.**
- {{Language-specific: error types, no unwrap on input-derived data, unsafe
  policy, allocation policy on the hot path.}}
- Every commit leaves the `CHECKS` in `scripts/method.conf` green, including the
  complexity lint where the language has one.

## Testing

**Test data:** `docs/DATA.md` (what each data set is, what it covers, which file
to use for what), `docs/PROVENANCE.md` (where it came from, which tool version
made it, how to regenerate it) and `docs/TEST_DATA.md` (what is missing). Read
them before building a fixture. Synthetic data comes from seeded generators,
validated by a reader that is not ours; an expected result is never produced by
the code under test (`test-data` skill).

| Tier | When | What |
| --- | --- | --- |
| **Small** | every task, before its commit | the task's own tests, at the depth its mode sets, with literal fixtures, and a fast smoke run of the real program. Seconds. |
| **Comprehensive** | every phase, before its push | the phase exit criterion on the real data, `scripts/gate.sh <n>`, the conformance comparison once it exists, and what the phase's mode adds |

- Compare with the authority the way it can be compared: semantically when its
  output is not byte-reproducible. Byte-for-byte is the test for **our** output
  against itself: two runs over one input give identical bytes.
- Known, accepted differences live in `docs/DIVERGENCES.md` with a reason each.
- A feature may ship unvalidated only if it is a **leaf** (nothing reads its
  output) and it is registered in `docs/UNVALIDATED.md`.

## Tests that cannot fail

The most common defect in agent-built code: the test observes something *near*
the behaviour it names instead of the behaviour itself.

**The self-referential fixture** — input built from the same named constant the
test asserts against moves with any mutation, so the test cannot fail. Rules:

1. **A fixture is literal data, never the constant under test.**
2. **Every table of magic numbers gets one test pinning each value to a literal,
   with its citation.**

For every test: *could this still pass if the behaviour it names were broken?*
Then prove it — break the implementation, run that one test, watch it fail,
revert. Prefer tests that run the real program and read its real output.

## Working agreement

### Before a phase starts

The phase is **prepared** (`prepare-phase` skill): its tasks are in a fixed
order with dependencies stated, grouped for implementation, every question that
affects it is answered, its fixtures are located, and its gate script exists. The
plan marks this with `Prepared: <date>` under the phase heading. **An
unprepared phase is not started.**

### One task, one commit

1. The **implementer** implements the task and its small tests on `main`.
2. Marks it ◐ in the plan (implemented, awaiting verification) and commits:
   `T2.3: <what>` with the trailer. One task, one commit — tasks implemented in
   one session as a group still get a commit each.
3. `scripts/task-audit.sh T2.3` passes.
4. The **verifier** — an independent, read-only agent — checks the commit against
   the task and reports problems **with a suggested repair for each**.
5. The implementer repairs (further commits, same task id); a recheck confirms.
6. On a pass, the task is marked ☑ in a commit `T2.3: verified`.

Plan markers: ☐ not started · ◐ committed, not yet verified · ☑ verified.
Only the task's own commits change its marker.

### The push is the phase

Commits accumulate on local `main`. `git push` happens once per **phase**, after
`scripts/gate.sh <n>` and the comprehensive tests pass. Subphases (2A, 2B …) get
their own checkpoint run of the gate but are not pushed alone. Pushing earlier is
allowed only when someone needs the work, and then `docs/STATUS.md` says plainly
that the gate has not passed.

`main` moves forward only: no rebase, squash, amend or force-push once pushed.
Phase-level commits that belong to no task use the prefix `P<n>: `.

### Questions that arise during implementation

Not everything can be anticipated. When a question comes up:
- Record it in `docs/QUESTIONS.md` (`Q-n`, the task that raised it, blocking or
  not, the options).
- **Blocking** (the answer changes what the task builds): stop the task and ask
  the owner.
- **Non-blocking:** proceed on a stated assumption, written in the entry and in
  the commit message.
- Every open question is answered by the owner **before the next phase is
  prepared**; an answer that contradicts an assumption becomes a task.

### New feature requirements found during implementation

Record each in `docs/FEATURES.md` (`F-n`); do not build it inside the current
task. At the phase's triage the owner gives each one a disposition: a new task in
a later phase of this cycle, **a future cycle**, or rejected. If input can reach
an unbuilt feature, the code refuses or visibly skips it.

### Failure is a stop, not a workaround

When a task cannot be completed, stop and report: what was attempted, the exact
failure output, the likely cause, the decision needed. Do not commit red, weaken
or delete a test, record a real diff as a divergence to get past it, skip ahead,
or silently reduce scope.

### Progress, pausing and resuming

- Progress is reported after every task: one line — task, commit, verified or
  not, what is next. `scripts/progress.sh` prints the whole picture from the plan
  and git.
- **All state lives in git** (plan markers and commits), so work can stop at any
  point. When a usage or rate limit is reached, the run **pauses**: finish or
  abandon the current step cleanly (never leave a half-edited tree committed),
  record the pause and the reset time in `docs/STATUS.md` → *Current run*, and
  stop. Do not retry in a loop.
- After the reset, the `resume` skill reads `scripts/progress.sh`, verifies every
  ◐ task first, then continues with the next ☐ task.

## Token discipline

- **Mechanical checks are scripts** (`task-audit.sh`, `gate.sh`, `progress.sh`);
  never re-derive them in prose. A new way to fail gets a new check, proven to
  bite.
- **Targeted tests while working, the full suite once** per task; determinism
  re-runs only at the gate.
- **A repair is rechecked against its problem list**, not re-verified from scratch.
- **Preparation happens once, before the phase**, so the run does not rediscover
  prerequisites.
- **Group tasks that share context** into one implementer session; commit each
  task separately; in prototype mode one verifier takes a whole group.
- **The prototype is the cheap mode on purpose.** Do not add harness, edge-case
  handling or polish to a prototype task — record it in `docs/FEATURES.md` for
  harnessing instead.
- **Observations are triaged or not requested.** A dead agent is not a pass.

## Registers

| File | Records |
| --- | --- |
| `docs/STATUS.md` | where the project is; the current run, pauses |
| `docs/QUESTIONS.md` | questions, their answers and who gave them |
| `docs/FEATURES.md` | new features and deferred hardening, each with a disposition |
| `docs/BACKLOG.md` | defects and improvements in what was built, not blocking |
| `docs/DIVERGENCES.md` | we differ from the authority on purpose, and why |
| `docs/UNVALIDATED.md` | we have not checked whether we match; leaves only |
| `docs/DATA.md` | what the test data is and covers; how to synthesize more |
| `docs/MEASUREMENTS.md` | choices decided by measurement; every performance claim's evidence |
| `docs/PROVENANCE.md`, `docs/TEST_DATA.md` | test data origin; what is missing |

Prose that describes behaviour is checked against the behaviour like code is.

## Conventions

- {{formatter/lint configuration, package and binary names}}
- Work through the plan in order. Do not start a task while an earlier one in
  the same subphase is ☐ or ◐.
