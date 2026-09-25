# phased-dev — cheat sheet

**You** write the concept, make the decisions, review the results. **The agent** designs, plans, builds, verifies, reports.

**Install:** `claude plugin marketplace add JuliusBrussee/caveman` · `claude plugin marketplace add rysavy-ondrej/phased-dev` · `claude plugin install phased-dev@phased-dev`

**Flow:** write `docs/CONCEPT.md` → `start` → `specify` → `plan` → each phase: `prepare-phase` → `implement` → `gate`

## Skills — type `/phased-dev:<skill>`

| Skill | Does | Your part |
| --- | --- | --- |
| `git-setup` · `dev-env` | check git, gh and tools; install with consent | `! gh auth login` |
| `start` | scaffold the repo, read your concept | write the concept |
| `specify` | spec by levels: scope, architecture, tech, components, rules | pick options per level |
| `test-data` | describe sample data; generate synthetic data | say if it is sensitive |
| `plan` | work per mode; phases 1..N, subphases A/B/C | confirm the modes |
| `prepare-phase` | task order, gate script, open questions | answer questions |
| `implement` | per task: code, tests, commit ◐, verify, ☑ | read progress |
| `gate` | full tests, review, phase report, push | decide new features |
| `status` | progress, open questions, next step | — |
| `question` · `feature` | record a question · a new idea | answer · decide |
| `measure` | benchmark candidates, write a report | choose one |
| `resume` | continue after a usage limit or a break | — |

Unattended: *"Run the run-phase workflow for phase N."* (more agents, more tokens)

## Modes — stages of the project

| Mode | Goal | Tests per task | Review |
| --- | --- | --- | --- |
| **prototype** | works end to end, cheaply | one demo test | short |
| **harnessing** | trustworthy: edge cases, conformance | every behaviour | 2 lenses |
| **production** | complete, robust, fast, packaged | + fuzzing | full panel |

**Tasks:** ☐ to do · ◐ committed · ☑ verified. **Commit** per task, **push** per phase.
**Always:** the authority wins · refuse visibly, never answer wrongly · tests must be able to fail · failure = stop.

## Files in `docs/`

`CONCEPT` yours · `SPEC` design + decisions · `IMPLEMENTATION_PLAN` phases, tasks · `STATUS` where we are · `QUESTIONS` · `FEATURES` · `MEASUREMENTS` · `DATA` · `ENVIRONMENT` · `BACKLOG` · **`reports/<proj>_phase_N.md` — what was done, how to try it.** Rules for agents: `CLAUDE.md`.

## Shell and troubleshooting

| Situation | Do |
| --- | --- |
| Where are we? | `scripts/progress.sh` (add `next` or `questions`) |
| Tool missing, gh signed out | `scripts/check-env.sh` → `dev-env` / `git-setup` |
| Caveman marketplace missing | add it (see Install), install again |
| Implement won't start | not prepared, blocking question, dirty tree → `status` |
| Stopped, usage limit | `status`, then `resume` after the reset |
| Chat too terse | `/caveman lite` or `/caveman off` |

Step-by-step guide: **HOWTO.md** · how the method works: `method` · where a gap is recorded: `registers`
