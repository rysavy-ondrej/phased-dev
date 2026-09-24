# Verifier prompts

Fill the `<...>` parts and pass to an Agent (general-purpose, high effort).
Do not paste CLAUDE.md into the prompt — the agent reads it.

## Verify a unit

```
Adversarially verify <T2.1, T2.2, T2.3> in <repo>, committed on main. Assume the
work does NOT meet its specification until the evidence forces the opposite.

## Read-only
Do NOT run git checkout, switch, merge, reset, commit, stash or rebase. Inspect
with git log/show/diff. Revert any scratch edit and confirm `git status
--porcelain` is empty before finishing.

## First, the mechanical audit
scripts/task-audit.sh <each id>
Every FAIL line is a problem, copied verbatim with its task id. Do not re-check
by hand what the script checks.

## The specifications
<each task's requirement, quoted verbatim from the plan, and its small-scale test>

## What the implementer reported
<summary; per task, the assertion the claim rests on>

## What to check
- Every requirement genuinely implemented, or stubbed, partial, quietly narrowed?
  Quote the requirement, then the code.
- CLAUDE.md "Tests that cannot fail" is binding.
  [production] For every test: could it pass if the behaviour were broken? Prove
  it: break the implementation at the exact construct the test names, run that
  one test, watch it fail, revert.
  [prototype] For each task, the ONE assertion its claim rests on: break the
  implementation behind it, run that test, watch it fail, revert. A central claim
  that survives mutation is a defect.
  Check fixtures for the self-referential shape.
- Run the real program on the real data. Hunt for an input giving a wrong result.
- Does prose the work added (help, doc comments, docs/*.md) claim something the
  code does not do?
- Between tasks of a batch: a helper one added that another works around; a
  requirement each assumed the other covered.
- [prototype] Anything parked in docs/OUT_OF_SCOPE.md that the requirement asks
  for is scope reduction — a problem. Input reaching a parked feature must be
  refused or visibly skipped, never a plausible wrong result.

## Running tests
Targeted tests for mutation proof; the whole suite once at the end.

## Output
pass: false ONLY for a reproduced defect.
problems: each with task id, file:line and the reproducing command.
observations: judgement calls — they do NOT fail the unit; written to make sense
to someone who never saw this task.
evidence: what you ran and what it printed.
```

## Recheck a repair

```
<ids> in <repo> was repaired (round <n>). Decide whether the repair worked.
Assume it did not. [Read-only section as above.]

The problems it was supposed to fix:
<numbered list>

1. scripts/task-audit.sh for each id; every FAIL is a problem.
2. For EACH problem: reproduce the original failure against the code now. It
   must no longer reproduce. "Fixed" by rewording, deleting a test or narrowing
   an assertion is not fixed.
3. For each: break the fix, run the covering test, watch it fail, revert.
4. Read the repair diff only; judge whether it broke a neighbour.
Do NOT re-derive the whole unit. Same output format.
```
