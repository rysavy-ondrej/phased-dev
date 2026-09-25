---
name: status
description: Report the actual state of a phased-dev project's implementation — current mode, phase and subphase progress (tasks not started, committed-unverified, verified), unpushed work, pause state, the list of open questions (blocking first), features awaiting the owner's decision, and the next step. Use when the user asks for status, progress, where the project is, what is left, or what questions are open.
---

# Status

Report from the repository, not from memory. Read-only: change nothing.

## 1. Gather

```bash
scripts/progress.sh            # tasks per mode / phase / subphase, counts, next step
scripts/progress.sh questions  # open questions, blocking marked
git log --oneline -5
git status --porcelain
```

Also read:
- `docs/STATUS.md` → mode, *Current run* (paused? why? reset time?), next action;
- **before implementation starts** (mode: specification): `docs/SPEC.md` →
  *Progress* (which level is confirmed, which is proposed and waiting for the
  owner) and the last rows of its *Decision log*;
- `docs/QUESTIONS.md` → *Open*, for each open question's options and the
  assumption work is proceeding on;
- `docs/FEATURES.md` → entries with `Disposition: proposed`;
- the last phase's gate result in STATUS, if the current phase has not been gated.

If the scripts are missing (a project that predates them), derive the same from
the plan's markers and `docs/` by hand, and say so.

## 2. Report

Keep it short and in this order:

1. **Where**: in specification — the level reached, which level waits for the
   owner's decision and on what (`Level 1 — architecture: proposed, 2 decision
   points open`). In implementation — mode, phase/subphase, `x/y tasks verified` for the current phase,
   and whether the previous phase is pushed. One compact table of phases in the
   current mode if there are several.
2. **State of the run**: running / paused (reason, reset time) / blocked (on
   which question or failure) / between phases. Uncommitted changes, if any.
3. **Open questions** — every one, blocking first:
   `Q-7 [BLOCKING] Which output encoding? — affects phase 2 — recommended: UTF-8`.
   For non-blocking ones, the assumption in force. Say which must be answered
   before the next phase can be prepared.
4. **Awaiting the owner**: spec decision points and levels to confirm, features
   with a `proposed` disposition, a push waiting for confirmation, a mode
   allocation not yet confirmed.
5. **Next step**: from `scripts/progress.sh next`.

Offer to answer the open questions now (AskUserQuestion, one round) — answering
them is usually the owner's most valuable next action.
