---
name: implement
description: Step 5: implement a prepared phase task by task — tests, one commit per task (◐), audit, independent verifier with suggested repairs, ☑ — with a progress line per task and a clean pause at usage limits. Use to implement a task, subphase or phase.
---

# Implement

Read `CLAUDE.md` (binding — especially *Modes* and *Working agreement*), the
phase in `docs/IMPLEMENTATION_PLAN.md` with its *Preparation*, and
`scripts/method.conf`. Run `scripts/progress.sh`.

**Preconditions — each missing one is a stop:** the phase has `Prepared:
<date>` (otherwise run `prepare-phase`); no open *blocking* question affects it
(`scripts/progress.sh questions`); the tree is clean and the `CHECKS` are green;
`scripts/phase<N>-gate.sh` exists.

The phase's **mode** (the `# Prototype / # Harnessing / # Production` heading
above it) sets test depth, verification and repair rounds (`CLAUDE.md` →
*Modes*). In prototype mode, resist doing more; record what you skip as
hardening (`feature`).

## Roles

- **Implementer** — writes the code and small tests and commits. By default the
  main session (its context is already loaded); for an unattended run, an agent
  per implementation group (the `run-phase` workflow).
- **Verifier** — an independent, read-only agent. Checks the commit against the
  task and returns reproduced problems, **each with a suggested repair**. It
  never edits code.

## The loop

Work through the implementation groups in the prepared order. In each group,
steps 1–6 run **per task**; steps 7–10 run per **verification unit** — the whole
group in prototype mode, each task otherwise. The next group starts when the
previous one is ☑.

1. **Implement** the task inside its module, behind its contract, using the
   pattern the spec names, within the complexity budget. Real code; the only
   placeholder allowed is an explicit refusal ("not supported yet: F-n") where
   the plan says so. Needing to change a contract, add a pattern or cross a
   boundary is a question, not a decision. A task turning out bigger than its
   plan line is split (record it, tell the owner) rather than implemented large.
2. **Small tests** in the same commit, at the mode's depth. Fixtures are literal
   data, never the constant under test; a new table of magic numbers gets a test
   pinning each value to a literal with its citation. Run targeted tests while
   working, the full suite once before committing.
3. **Questions** that come up → `question` skill. Blocking: stop the task and
   ask. Non-blocking: continue on a stated assumption (in the entry and the
   commit message).
4. **New features** that come up → `feature` skill. Never built inside the task.
5. **Commit**: mark the task ◐ in the plan (that line only — a sed on `T1.1` also
   hits `T1.10`), commit `T2.3: <what>` with the trailer. This subject form
   wins over any commit-message skill (e.g. `caveman-commit`).
6. **Audit**: `scripts/task-audit.sh T2.3` must exit 0; fix with a further
   `T2.3:` commit.
7. **Verify**: spawn one Agent (general-purpose, high effort) with the prompt in
   `references/verifier-prompt.md` for the unit's mode — not a caveman reviewer,
   whose one-line findings lack the reproduction and the repair. A verifier that
   returns nothing verified nothing: re-run it.
8. **Repair**: for each reproduced problem, apply (or improve on) the suggested
   repair in a further commit under the task's id, add the test that would have
   caught it, and have a **recheck** agent confirm against that problem list
   only. Rounds: prototype 1, otherwise 3. Problems that survive are a stop.
9. **Mark verified**: flip ◐ → ☑ for each task of the unit, one `T2.3: verified`
   commit per task. Keep the verifier's non-blocking observations for the phase
   triage (a running list, or straight into `docs/BACKLOG.md`).
10. **Report progress** — one line to the user (required output, also in caveman
    mode):
    `T2.3 ☑ (a1b2c3d, 0 repairs) — 4/7 in phase 2 — next: T2.4`.
    Update `docs/STATUS.md` → *Current run* at the end of each group.

At the end of a **subphase**, run `scripts/gate.sh <N><sub>` as a checkpoint.
At the end of the **phase**, go to `gate` — the push happens there.

## Measurement tasks

A task that measures (`Measure M-n …`) follows the `measure` skill instead of
steps 1–2: minimal candidates behind the contract, correctness first, then the
benchmark, then the report. Its commit is the report with its raw data. The
verifier re-runs the correctness check and a subset of the measurements and
checks the report is reproducible from its commands. After ☑, the owner's
decision is a blocking question for every task that depends on the choice.

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

As `CLAUDE.md` says: report what was attempted, the exact output, the likely
cause and the decision needed — never work around it.
