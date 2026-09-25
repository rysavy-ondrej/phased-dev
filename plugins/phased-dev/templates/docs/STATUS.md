# Status

Updated {{date}}.

This file says where the project **is**. How it got here moves to
`docs/history/phase-<n>.md` when a phase closes.

## Current run

Mode {{prototype | harnessing | production}}, phase {{n}}{{subphase}}. `scripts/progress.sh` is the authority for
task state; this section records what it cannot:

<!-- Paused: yes — <reason, e.g. usage limit>, at <time>, resets at <time> -->
- Paused: no
- Next step on resume: {{verify T2.3 | implement T2.4}}
- Blocked on: {{Q-n | nothing}}

## Phases

| Phase | Mode | State |
| --- | --- | --- |
| 1 — {{title}} | prototype | Not started. |

`git log --oneline origin/main..main` is the authority for what is unpushed. Do
not quote a commit count here: it goes stale.

## Next action

{{one line}}
