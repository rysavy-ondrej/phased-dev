# Out of scope

Features and hardening this prototype **deliberately does not build**, because
they do not serve the question in `CONCEPT.md`. They came up during
specification or development, which is normal; this file keeps them from being
either built by accident or forgotten.

| File | Means |
| --- | --- |
| `BACKLOG.md` | something we built has a defect or could be better |
| `UNVALIDATED.md` | something we built has not been checked |
| `DIVERGENCES.md` | something we built differs from the authority on purpose |
| **This file** | something we **did not build**, on purpose |

## Rules

1. **Park, do not build.** When a feature outside the question appears — in a
   spec discussion, in the authority, in the middle of a task — write an entry
   and carry on. Do not implement it "while you are there".
2. **Park, do not drop.** Silence is the failure mode: an unrecorded omission
   looks exactly like an oversight at graduation.
3. **The code does not pretend.** If input can reach a parked feature, the
   program refuses or skips it visibly (an error naming `OOS-n`, or a counted
   skip on the diagnostic channel) — never a plausible wrong result.
4. **Promotion is the owner's decision.** An entry becomes a plan task only by a
   dated ruling; its status then names the task.
5. Ids are never reused.

## Parked features

<!--
### OOS-1 — {{short name}}
**Raised:** {{task or spec section}}, {{date}}.
**What:** {{the feature, one or two sentences.}}
**Why out of scope:** {{why the question does not need it.}}
**If reached:** {{what the prototype does when input needs it — refuses with ..., skips and counts ...}}
**Would need:** {{rough size; the seam it would plug into.}}
**Status:** parked | promoted to Tn.m ({{date}}) | rejected ({{date}}, why)
-->

## Deferred hardening

Things a production version would have and this prototype does not: fuzzing,
malformed-input suites, portability, polished errors, benchmarks. One line each,
with where it would apply. This is the checklist graduation starts from.

- (none yet)
