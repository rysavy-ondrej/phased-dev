# {{PROJECT}} — agent context

Read this file before touching any code. It records the invariants that are easy
to get wrong and expensive to discover late. It is injected into every agent, so
it is the one place a rule lives; prompts name a rule, they do not restate it.

**Profile: {{PROFILE}}.** See *Profile* below for what that changes.

## What this project is

{{WHAT_IT_IS — two or three sentences: what the program does, its inputs and its
outputs. Link docs/CONCEPT.md for the long form.}}

{{WHY_IT_EXISTS — the one reason the project exists (throughput, a new
capability, answering a research question), and the one constraint on it (must
produce the same results as X, must run on Y).}}

### What wins when they conflict, in this version

1. **{{PRIME}}** — the prime directive below. Never traded for anything.
2. **Never crash on input, never break the output contract, never lie in the output.**
3. **Functionality and simplicity.** A straightforward implementation that is
   obviously correct beats a faster one that is harder to read, harder to prove,
   or carries a failure mode the simple version does not have.
4. **Speed.**

This is about **proportionate effort**, not about preferring slow code. When the
efficient shape is the natural one to write — the right data structure, the
linear pass, reuse instead of per-item allocation — it is simply the right code.
What is not warranted is *disproportionate* effort: elaborate machinery, new
failure modes or new invariants to maintain, bought for a gain nobody has
measured a need for. If the faster version costs a week or a new way to fail,
write the plain one, record the choice and its measured cost as a settled
decision, and leave the optimisation to a phase that has a benchmark in hand.

A task's plan text naming a technique is a strong hint, not a mandate: it was
written before the code existed. When it turns out to cost more than it is
worth, say so in the commit rather than quietly substituting something else.

## The prime directive: {{PRIME}}

{{AUTHORITY — name the normative source: a reference implementation, a standard,
a set of golden outputs, a paper's algorithm. Say where its copy lives in the
repo (e.g. docs/reference/), and that it is read-only.}}

**When this document, the README, or your own judgement disagrees with the
authority, the authority wins** — file an issue, do not silently "improve" the
behaviour. Read the authority, extract its observable contract, then implement
that contract with sensible data structures. The authority is the spec, not the
design.

### Invariants (verified against the authority)

List the ones a sensible from-scratch design gets **wrong by default**. Each one
names where in the authority it comes from, so it can be re-checked.

1. {{INVARIANT — e.g. "ids are assigned in order of first appearance and survive
   a flush"; cite file:line of the authority.}}

Where the authority is itself non-deterministic or buggy, say so here, say what
we emit instead, and record it in `docs/DIVERGENCES.md`.

## Architecture seams

Each seam exists so one axis of change stays contained; adding to one must never
require touching the others.

| Seam | Location | Contains the change of... |
| --- | --- | --- |
| {{Trait/interface}} | {{path}} | {{what varies behind it}} |

If two seams ever need to know about each other, the split is wrong — fix the
seams rather than special-casing.

## The output contract

{{Where results go and what else may appear there. E.g. "During a run, stdout
carries records and nothing else; diagnostics are stderr's." State which modes
are exempt (--help, --version) and why.}}

## Non-negotiables for the code itself

- **Never crash on input.** Malformed, truncated and hostile input is normal.
  Parsers return errors; indexing without a length check is a bug.
- **Never lie in the output.** Input the program does not handle is refused or
  skipped *visibly* (counted, logged on the diagnostic channel), never turned
  into a plausible wrong result.
- {{Language-specific rules: error types, no unwrap on input-derived data,
  unsafe policy, allocation policy on the hot path.}}
- Every commit leaves `{{CHECK_COMMANDS}}` green.

## Profile

<!-- profile:production -->
**production.** Everything this project ships is trusted by someone else, so
every claim is verified before it lands.

- One task, one commit. Each task is adversarially verified — per task, or per
  planned group — with mutation proof of every test it adds.
- Tests cover the malformed and hostile variants, not only the happy path;
  anything that indexes into untrusted bytes gets a fuzz target.
- Each phase ends with the full-scale test and a review panel (seams, tests,
  robustness, conformance, plus a completeness critic).
<!-- /profile:production -->
<!-- profile:prototype -->
**prototype.** This project exists to answer a question, stated in
`docs/CONCEPT.md` under *The question*. Harness and hardening are proportional to
that question, not to a product that does not exist yet.

- **Harness proportional to the question.** Test every claim the answer depends
  on — anything that feeds a result someone will read. Do not build: fuzz
  targets, exhaustive malformed-input suites, CLI polish, portability shims,
  exit-code taxonomies, or benchmarks (unless the question is about
  performance). Each thing deliberately not built is one line in
  `docs/OUT_OF_SCOPE.md` under *Deferred hardening*, so graduation knows what it
  owes.
- **What is not relaxed:** the prime directive, never lying in the output, no
  hollow test for a claim that is made, and *failure is a stop*. A prototype that
  produces a confident wrong answer has failed at the only thing it is for.
- **Work is batched, and the batching is planned before code.** See
  *Token discipline* and `docs/IMPLEMENTATION_PLAN.md`: each phase is cut into
  batches of tasks that share context and are verified together. One batch, one
  commit, one verification pass.
- **Features outside the question are parked, not built and not dropped.** They
  will come up during specification and development — that is normal. Record
  each in `docs/OUT_OF_SCOPE.md` (a few lines), make the code refuse it
  explicitly if input can reach it, and carry on. Promoting one into the plan is
  the owner's decision, never the implementer's.
- Each phase ends with the gate script, the phase's exit demonstration, and one
  combined review — not a panel.
<!-- /profile:prototype -->

## Testing

**Test data provenance.** {{Where test data lives. If it is not in git, say so,
and point to docs/PROVENANCE.md (where each set came from, how to regenerate it)
and docs/TEST_DATA.md (what is still missing).}} Read both before assuming a
fixture does or does not exist.

- Every task ships its tests in the same commit as the code. A task is done when
  it is covered, not when it runs.
- Compare against the authority the way the authority can be compared: if its
  output is not byte-reproducible, compare semantically (multisets, normalised
  records) and report the first difference. Byte-for-byte is the test for **our**
  output against itself: two runs over the same input produce identical bytes.
- Known, accepted differences from the authority live in `docs/DIVERGENCES.md`
  with a reason each. An empty diff is the goal; an undocumented diff is a
  failure.
- **Not every feature has to be validated the moment it ships.** Where no
  authority is reachable, a feature may ship unvalidated *if it is a leaf* —
  nothing in the codebase reads its output — and it is registered in
  `docs/UNVALIDATED.md` with what would close it. Anything other code trusts is
  validated before it ships, and an entry stops qualifying the moment something
  starts depending on it.
- Do not regenerate a golden with a different tool version and call it a fix: a
  regenerated golden is a new baseline, not a corrected one. Ask first.

## Tests that cannot fail

The most common defect in agent-built code. The shape: the test observes
something *near* the behaviour it names instead of the behaviour itself —
unit-testing a helper under conditions the real program never has, asserting a
substring whose boundaries are not pinned, checking a value two fields happen to
share.

**The self-referential fixture.** A test builds its input out of the same named
constant it asserts against, so the fixture moves with any mutation and the test
cannot fail. Two rules, both cheap:

1. **A fixture is literal data, never the constant under test.** Write `0x2b` in
   the byte array, not `ROUTING`.
2. **Every table of magic numbers gets one test pinning each value to a literal,
   with its citation.** `assert_eq!(ROUTING, 43); // RFC 8200 §4.4` looks
   tautological and is not: it turns a silent behaviour change into a visible,
   reviewable edit.

For every test: ask **"could this still pass if the behaviour it names were
broken?"**, then **prove the answer** — break the implementation, run that one
test, watch it fail, revert. Prefer a test that runs the real program and reads
its real output over one that inspects a component in isolation. A hollow test
is worse than none: it converts an unknown into a false assurance.

## Token discipline

Agent effort is a budget. These rules exist because each was measured being
wasted.

- **Mechanical checks are scripts, not agents.** `scripts/task-audit.sh` and
  `scripts/gate.sh` check everything that needs no judgement. Run them; never
  re-derive their checks in prose. When a new way to fail appears that they
  cannot see, add the check to the script and prove it bites.
- **Targeted tests while working, the full suite once.** Mutation proof needs the
  one test being mutated. Determinism re-runs happen once, at the gate.
- **A repair is rechecked against its problem list**, not re-verified from
  scratch.
- **A readiness check precedes every phase**: fixtures, dependencies, open
  owner decisions, existing CLI surface — found once, written into the plan, so
  the run spends its effort on the work and not on rediscovering prerequisites.
- **Observations are triaged into `docs/BACKLOG.md` or they are not asked for.**
- **A dead agent is not a pass.** An agent that returned nothing verified nothing.
<!-- profile:prototype -->
- **Plan batches before implementing.** Reading context is the dominant cost of
  an agent; a batch amortises one read over several tasks. Implement a batch in
  one session, commit it once, verify it once.
- **Default to no subagent.** The main session implements; one independent
  verifier per batch is the only subagent a batch needs.
<!-- /profile:prototype -->

## Working agreement

This is the process the implementation follows. It is not advisory.

### Linear history

1. Implement the {{UNIT}} and its tests on `main`.
2. Verify green with the commands in `scripts/method.conf`.
3. Commit with the task id(s) leading the subject: `T1.3: read the input file`,
   or for a batch `T2.1, T2.2, T2.3: decode the transport layer`.
4. Independent verification runs against that commit. Anything it finds is fixed
   with further commits carrying the same id(s).
5. `scripts/task-audit.sh <id>` passes. Next {{UNIT}}.

`main` moves forward only. Nothing is rebased, squashed or force-pushed once
pushed. Phase-level work that belongs to no task uses the prefix `P<n>: `.

### The push is the gate

Commits accumulate on local `main` through a phase. `git push` happens once, after
the phase's exit criterion has passed `scripts/gate.sh <n>`. Pushing earlier is
allowed only when someone genuinely needs the work, and then `docs/STATUS.md`
says plainly that the gate has not passed and why. Silence about a failed gate is
the violation; the push is not.

### Two tiers of testing

| Tier | When | What |
| --- | --- | --- |
| **Small-scale** | every {{UNIT}}, before its commit | Unit tests on its own code, literal fixtures, a fast smoke run of the real program. Seconds. |
| **Full-scale** | every phase, before push | The phase exit criterion run for real on the real data, the conformance comparison once it exists, and whatever the profile adds. |

### Failure is a stop, not a workaround

When a task cannot be completed — the approach does not work, a test fails and
the fix is not obvious, the authority will not match, a plan assumption is wrong
— **stop and report it**. Do not commit red, weaken or delete a test, record a
real diff as an accepted divergence to get past it, skip ahead, or silently
reduce scope. Report what was attempted, the exact failure output, and the likely
cause. A blocked task is useful information; a quietly downgraded one is not.

## Documentation

| File | Says |
| --- | --- |
| `docs/CONCEPT.md` | why the project exists, for whom, what is in and out |
| `docs/IMPLEMENTATION_PLAN.md` | phases, tasks, exit criteria, settled decisions |
| `docs/STATUS.md` | where the project *is* now; history moves to `docs/history/` |
| `docs/DIVERGENCES.md` | we know we differ from the authority, and why |
| `docs/UNVALIDATED.md` | we do not know whether we match; leaves only |
| `docs/BACKLOG.md` | real defects and improvements judged not blocking |
<!-- profile:prototype -->
| `docs/OUT_OF_SCOPE.md` | features parked because they do not serve the question, and hardening deferred |
<!-- /profile:prototype -->
| `docs/PROVENANCE.md` | where every test-data set came from, how to regenerate it |

Prose that describes behaviour — help text, doc comments, these files — is
checked against the behaviour like code is. A sentence that states what the code
does not do is a defect, however correct the code beside it.

## Conventions

- {{Language, edition, formatter config, lint config.}}
- {{Binary/package names.}}
- Work through `docs/IMPLEMENTATION_PLAN.md` in order. Do not start a task while
  an earlier one in the same phase is incomplete.
