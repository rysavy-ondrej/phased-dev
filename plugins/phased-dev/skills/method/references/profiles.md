# Profiles compared

| Aspect | production | prototype |
| --- | --- | --- |
| Purpose | output trusted by others | answer *the question* in `CONCEPT.md` |
| Unit of work | task (optionally a planned group) | batch of tasks, planned before code |
| Commit | one per task: `T1.3: ...` | one per batch: `T2.1, T2.2, T2.3: ...` |
| Implementer | one agent per task | the main session, or one agent per batch |
| Test depth | happy path, malformed and truncated variants, hostile input, fuzz targets for anything indexing untrusted bytes | every claim the answer depends on; the one edge case that would make a result lie |
| Mutation proof | every test, by implementer or group verifier | the central assertion of each task, by the batch verifier |
| Verification | adversarial per task/group | one verifier per batch |
| Repair rounds | up to 3, each rechecked against its problem list | 1, then stop and report |
| Phase gate | `gate.sh` + exit criterion on full data + DIVERGENCES re-run | same, plus OUT_OF_SCOPE "If reached" lines checked |
| Review | seams, tests, robustness, conformance + completeness critic | one combined lens |
| Registers | STATUS, BACKLOG, DIVERGENCES, UNVALIDATED, PROVENANCE, TEST_DATA | all of those + OUT_OF_SCOPE |
| Benchmarks | when a phase claims performance | only if the question is about performance |
| Unvalidated leaves | allowed, registered | allowed, registered (same leaf rule) |

## Never relaxed, in either profile

- The prime directive (conformance with the authority).
- Never lie in the output: unsupported input is refused or skipped visibly.
- No hollow test for a claim that is made.
- Failure is a stop, not a workaround; no weakened test, no silent scope cut.
- Linear history, task ids in subjects, the push is the gate.
- Mechanical checks are scripts.

## Choosing

Choose **prototype** when the main deliverable is knowledge (feasibility, a
number, a demonstration) and the code may be thrown away or rewritten. Choose
**production** when anyone other than the author will run the output and trust
it. When unsure, ask the owner; it is their call and it changes the plan's shape.

## Graduation checklist (prototype → production)

1. Change `PROFILE` in `scripts/method.conf` and the *Profile* section of
   `CLAUDE.md` (re-run `scaffold.sh --force` into a scratch dir and copy the
   production block).
2. Every *Deferred hardening* line becomes a task or a settled decision not to.
3. Every parked `OOS-n` gets a dated ruling: promoted to a task, kept out (and
   moved to the concept's *Out of scope*), or rejected.
4. Every `UNVALIDATED.md` entry is re-checked against the leaf rule — graduation
   usually adds consumers, and a consumer disqualifies an entry.
5. The first production phase re-runs the full review panel over the prototype's
   code, not only over the new diff.
