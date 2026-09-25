---
name: resume
description: Resume paused or interrupted phased-dev work — after a usage limit, a closed session or a stopped workflow — from git state: verify ◐ tasks first, then continue. Use when the user says resume or continue, or after a limit reset.
---

# Resume

All progress is in git: the plan's task markers (☐ ◐ ☑), the commits, and
`docs/STATUS.md` → *Current run*. Nothing needs to be remembered.

## 1. Reconstruct

```bash
git status --porcelain
scripts/progress.sh
scripts/progress.sh next
```

- **Dirty tree**: a step was cut off. Look at the diff before touching it. If it
  is a complete, green change for the current task, finish it (commit, audit).
  Otherwise restore only the files that task touched. Never discard work you
  have not looked at.
- **A workflow run** in this same session can be continued with Workflow's
  `resumeFromRunId` (completed agents replay from cache). Otherwise continue in
  session from git state as below.
- Read *Current run* for the reason of the pause and anything recorded there.

## 2. Check the limit has reset

If the pause was a usage or rate limit and its reset time is recorded and not
yet reached, say so and stop — retrying burns the reset. If the host offers a
scheduler, offer to schedule this skill for after the reset.

## 3. Continue in the right order

1. **◐ tasks first** — committed but not verified. Run the verifier on each
   (`implement` step 7 onward). Never mark them ☑ without it.
2. Then the next ☐ task in the prepared order (`implement` from step 1).
3. If a verifier or review lens died before the pause, re-run it; its result is
   missing, not clean.

Before continuing, check `scripts/progress.sh questions`: a blocking question
answered during the pause may change the next task.

## 4. Record

Set *Current run* to `Paused: no` and commit it with the next task (or as
`P<N>: resume`). Report to the user in one line where work resumed:
`Resumed phase 2 at T2.4 (T2.3 verified first) — 3/7 done`.
