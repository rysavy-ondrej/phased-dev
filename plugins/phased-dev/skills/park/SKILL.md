---
name: park
description: Record a feature or hardening item as out of scope for a prototype in docs/OUT_OF_SCOPE.md (an OOS-n entry), instead of implementing it or silently dropping it, and make sure the code refuses it visibly. Use when, during concept, specification, planning or implementation of a prototype, a feature comes up that does not serve the prototype's question, or when the user says "park this", "out of scope", "not for the prototype".
---

# Park

A prototype answers one question (`docs/CONCEPT.md` → *The question*). Features
outside it will come up — in the authority, in discussion, halfway through a
task. Building them wastes the budget; dropping them silently makes them look
like oversights later. Parking costs a few lines and keeps both honest.

## Decide: park, or not?

Park it when the question can be answered without it. Do **not** park:
- anything the current task's own requirement asks for — that is scope
  reduction, a stop to report to the owner, not a parking decision;
- anything whose absence would make the program produce a **wrong** result
  rather than a refused or skipped one — then the refusal is in scope, even if
  the feature is not.

If unsure whether the question needs it, ask the owner; do not decide by
implementing it.

## Write the entry

Append to `docs/OUT_OF_SCOPE.md` → *Parked features*, next free id (ids are
never reused — check the highest existing `OOS-n`):

```markdown
### OOS-7 — <short name>
**Raised:** <task id or spec section>, <YYYY-MM-DD>.
**What:** <the feature, one or two sentences>.
**Why out of scope:** <why the question does not need it>.
**If reached:** <what the program does when input needs it: refuses with an error naming OOS-7 / skips and counts it on the diagnostic channel / not reachable>.
**Would need:** <rough size; the seam it would plug into>.
**Status:** parked
```

Hardening rather than a feature (fuzzing, malformed-input suite, portability,
error polish, benchmark) is one line under *Deferred hardening* instead:
`- <what> — <where it would apply> (<task>, <date>)`.

## Make the code honest

If input can reach the parked feature, the *If reached* line must be true in
code: a refusal that names the entry, or a counted, visible skip. Add a test only
if the refusal protects a result from being wrong. Never emit a plausible
default in its place.

## Commit

With the current task's commit if it arose there; otherwise alone as
`P<N>: park <short name>` (phase-level prefix). Mention the id in your summary
so the owner sees what was parked.

## Promotion

Only the owner promotes an entry. Record it on the entry —
`**Status:** promoted to T4.3 (<date>, owner)` — and add the task to the plan.
Rejected entries stay, with the reason.
