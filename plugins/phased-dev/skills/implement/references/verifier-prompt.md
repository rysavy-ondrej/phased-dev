# Verifier prompts

Fill the `<...>` parts and pass to an Agent (general-purpose, high effort). Do
not paste CLAUDE.md — the agent reads it.

## Verify a task (or, in prototype mode, a group)

```
Verify <T2.3 | T1.1, T1.2, T1.3> in <repo>, committed on main. Mode: <prototype |
harnessing | production> (CLAUDE.md → Modes). Assume the work does NOT meet its
requirement until the evidence forces the opposite.

## Read-only
Do NOT run git checkout, switch, merge, reset, commit, stash or rebase, and do
not edit files except for scratch mutations you revert. Confirm `git status
--porcelain` is empty before finishing.

## First, the mechanical audit
scripts/task-audit.sh <each id>
Every FAIL line is a problem. Do not re-check by hand what it checks.

## The requirement
<each task's line from the plan, verbatim, with its small test>

## What the implementer reported
<summary; assumptions made on open questions; features recorded>

## What to check
- Is the requirement met, or stubbed, partial, quietly narrowed? Quote it, then
  the code.
- Run the real program on real (sample) data and look for a wrong result.
- Unhandled input: refused or visibly skipped — never a plausible wrong result.
- Prose the task added (help, doc comments, docs) matches the behaviour.
[prototype]
- The demonstration test really exercises the behaviour: break the behaviour,
  run that test, watch it fail, revert. One mutation per task is enough.
- Do NOT ask for edge cases, harness or polish — that is harnessing work. Put
  such remarks in observations, not problems.
[harnessing | production]
- Every new test can fail: break the implementation at the exact construct each
  test names, run that test, watch it fail, revert. Check fixtures for the
  self-referential shape (input built from the constant under test).
- Edge and malformed inputs the requirement names are handled and tested.
[production]
- Hostile input: find one the tests do not throw.

Run only the tests you mutate; the full suite once at the end.

## Output
pass: false ONLY for a defect you reproduced.
problems: each with task id, file:line, the reproducing command, and
  suggested_repair — the change you would make, concretely.
observations: judgement calls; they do NOT fail the task. Write each so it makes
  sense to someone who never saw this task.
questions: anything the requirement leaves ambiguous (becomes a Q-n).
evidence: what you ran and what it printed.
```

## Recheck a repair

```
<ids> in <repo> was repaired (round <n>). Decide whether the repair worked.
Assume it did not. [Read-only section as above.]

The problems it was supposed to fix:
<numbered list with the suggested repairs>

1. scripts/task-audit.sh for each id; every FAIL is a problem.
2. For EACH problem: reproduce the original failure against the code now. It
   must no longer reproduce. "Fixed" by rewording, deleting a test or narrowing
   an assertion is not fixed.
3. For each: break the fix, run the covering test, watch it fail, revert.
4. Read the repair diff only; judge whether it broke a neighbour.
Do NOT re-verify the whole task. Same output format.
```
