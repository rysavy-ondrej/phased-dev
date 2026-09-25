---
name: implement
description: Step 5 of the phased-dev method — implement a prepared phase of docs/IMPLEMENTATION_PLAN.md task by task in the prepared order; each task gets its small tests, one commit (marked ◐), the audit script, an independent verifier that checks it and suggests repairs, bounded repair rounds, and a ☑ commit when verified. Reports progress after every task, records questions and new features as they arise, and pauses cleanly at a usage or rate limit. Use when asked to implement a task, a subphase or a phase.
---

# Implement

Read `CLAUDE.md` (binding — especially *Modes* and *Working agreement*), the
phase in `docs/IMPLEMENTATION_PLAN.md` with its *Preparation*, and
`scripts/method.conf`. Run `scripts/progress.sh`.

**Preconditions — each missing one is a stop:** the phase has `Prepared:
<date>` (otherwise run `prepare-phase`); no open *blocking* question affects it
(`scripts/progress.sh questions`); the tree is clean and the `CHECKS` are green;
`scripts/phase<N>-gate.sh` exists.

The **mode** of the phase (the `# Prototype / # Harnessing / # Production`
heading above it) sets test depth, verifier strength and repair rounds —
`CLAUDE.md` → *Modes*. In prototype mode, resist doing more: no edge cases, no
harness, no polish. Record what you skip as hardening (`feature` skill).

## Roles

- **Implementer** — writes the code and small tests and commits. By default the
  main session (its context is already loaded); for an unattended run, an agent
  per implementation group (the `run-phase` workflow).
- **Verifier** — an independent, read-only agent. Checks the commit against the
  task and returns reproduced problems, **each with a suggested repair**. It
  never edits code.

## The loop, per task, in the prepared order

1. **Implement** the task. Real code; the only placeholder allowed is an explicit
   refusal ("not supported yet: F-n") where the plan says so.
2. **Small tests** in the same commit, at the mode's depth. Fixtures are literal
   data, never the constant under test; a new table of magic numbers gets a test
   pinning each value to a literal with its citation. Run targeted tests while
   working, the full suite once before committing.
3. **Questions** that come up → `question` skill. Blocking: stop the task and
   ask. Non-blocking: continue on a stated assumption (in the entry and the
   commit message).
4. **New features** that come up → `feature` skill. Never built inside the task.
5. **Commit**: mark the task ◐ in the plan (that line only — a sed on `T1.1` also
   hits `T1.10`), commit `T2.3: <what>` with the trailer.
6. **Audit**: `scripts/task-audit.sh T2.3` must exit 0; fix with a further
   `T2.3:` commit.
7. **Verify**: spawn one Agent (general-purpose, high effort) with the prompt in
   `references/verifier-prompt.md` for this task's mode. In prototype mode, when a
   whole implementation group is committed, one verifier takes the group. A
   verifier that returns nothing verified nothing — re-run it, never count it as
   a pass.
8. **Repair**: for each reproduced problem, apply (or improve on) the suggested
   repair in a further `T2.3:` commit, add the test that would have caught it,
   and have a **recheck** agent confirm against that problem list only. Rounds:
   prototype 1, harnessing/production 3. Problems that survive are a stop.
9. **Mark verified**: flip ◐ → ☑, commit `T2.3: verified`. Keep the verifier's
   non-blocking observations for the phase triage (a running list, or straight
   into `docs/BACKLOG.md` under the phase).
10. **Report progress** — one line to the user:
    `T2.3 ☑ (a1b2c3d, 0 repairs) — 4/7 in phase 2 — next: T2.4`.
    Update `docs/STATUS.md` → *Current run* at the end of each group.

At the end of a **subphase**, run `scripts/gate.sh <N><sub>` as a checkpoint.
At the end of the **phase**, go to `gate` — the push happens there.

## Pausing at a usage or rate limit

Work can stop at any moment; all state is in git, so stopping is safe if the
tree is clean.

- When a limit is reached (an agent dies with a limit error, or you are warned
  the session is near it), **do not start a new step and do not retry in a
  loop.** Finish the current commit if it is complete and green; otherwise
  discard the partial edit (`git restore`/`git clean` only on files this task
  touched — look before deleting).
- Record in `docs/STATUS.md` → *Current run*: `Paused: yes — <limit>, at <time>,
  resets at <time if known>` and `Next step on resume: <scripts/progress.sh next>`;
  commit it as `P<N>: pause`.
- Tell the user it is paused, why, and when it can resume. If the host offers a
  scheduler (a one-off scheduled task, `/loop`), offer to run `/phased-dev:resume`
  after the reset time.
- The `resume` skill continues: ◐ tasks are verified first, then the next ☐.

## Running unattended: the `run-phase` workflow

`.claude/workflows/run-phase.js` runs the same loop with agents. It spawns many
agents, so use it only when the user asks for an unattended run.
`{phase: 2}` runs the phase in the prepared order; `{phase: 2, subphase: "2A"}`
one subphase; `{only: ["T2.3"]}` named tasks; `{skipReview: true}` lands tasks
without the gate. When an agent dies (typically a limit), the workflow returns
`paused` with the next step instead of a verdict. Resume with Workflow's
`resumeFromRunId` in the same session (completed agents are replayed from cache),
or later with the `resume` skill, which reads git.

For a re-run of one or two known tasks, skip its Scope agent by passing the
briefs: `{phase: 3, tasks: [{id, slug, spec, smallScale}], notes, skipReview:
true}` — quote the requirement verbatim and name the code it extends.

## Failure is a stop

When a task cannot be completed, stop and report what was attempted, the exact
failure output, the likely cause, and the decision needed. Never commit red,
weaken a test, record a real diff as a divergence to get past it, skip ahead, or
silently narrow the task.
